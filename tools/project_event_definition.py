"""Projects one event site into a `kakyu_event_definition/v3` document.

Reads one catalog event row (`--catalog`/`--event`), the event name
registry (`--names`, a file or a directory holding `event_names.json` and
`names_fingerprint`), a local playback package (`--package`) and a replay
capture (`--replay`, produced by
`tools/content_suite/cli/replay_event_dialogue.gd`), verifies message
hashes against the read-only archive (`--arc`) and writes two files under
`--out`:

  <id>.json            the tracked projection (no inline text anywhere)
  <id>.resolved.json   the same document with every text_ref resolved

See docs/spec/data/event_definition_projection.md for the field mapping.
This tool never prints or writes original dialogue text except into the
resolved document.
"""

import argparse
import hashlib
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mes_route_decode import Archive, conjuncts  # noqa: E402

SCHEMA_VERSION = "kakyu_event_definition/v3"

TERMINAL_KIND_MAP = {
    "root_replacement": "root_handoff",
    "normal_completion": "root_handoff",
    "callee_return_only": "callee_return",
    "caller_handoff": "natural_handoff",
    "caller_postlude": "natural_handoff",
}


def catalog_terminal_kind(terminal):
    """v3 terminal kind for one catalog `terminals[]` row, decided from its
    catalog `kind` and, for `analysis_boundary` (the catalog uses one kind
    for two different runtime outcomes), `runtime_status`."""
    catalog_kind = terminal["kind"]
    if catalog_kind == "analysis_boundary":
        if terminal.get("runtime_status") == "def_selection_boundary":
            return "def_selection_boundary"
        return "dependency_stop"
    return TERMINAL_KIND_MAP.get(catalog_kind, catalog_kind)


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def load_json(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def find_event(catalog, event_id):
    for event in catalog["events"]:
        if event["event_id"] == event_id:
            return event
    return None


def load_registry(names_arg):
    """`names_arg` may be a directory (holding event_names.json and
    names_fingerprint) or a JSON file path directly. Returns
    (registry_document, names_fingerprint_or_"unrecorded")."""
    if os.path.isdir(names_arg):
        registry_path = os.path.join(names_arg, "event_names.json")
        fingerprint_path = os.path.join(names_arg, "names_fingerprint")
    else:
        registry_path = names_arg
        fingerprint_path = os.path.join(os.path.dirname(os.path.abspath(names_arg)), "names_fingerprint")
    registry = load_json(registry_path)
    if os.path.isfile(fingerprint_path):
        with open(fingerprint_path, "r", encoding="utf-8") as fh:
            names_fingerprint = fh.read().strip()
    else:
        names_fingerprint = "unrecorded"
    return registry, names_fingerprint


DEFAULT_CONTRACT_FINGERPRINT_PATH = os.path.join(
    "config", "contracts", "event_definition_v3", "contract_fingerprint"
)


def resolve_contract_fingerprint(value):
    """`value` may be a path to a fingerprint file or the literal
    fingerprint string itself; a path that does not exist is treated as a
    literal value (so `--contract-fingerprint unrecorded` still works)."""
    if value and os.path.isfile(value):
        with open(value, "r", encoding="utf-8") as fh:
            return fh.read().strip()
    return value


def find_registry_row(registry, event_id):
    """Supports the real registry shape (`rows`: {id: row}) and the local
    stand-in shape (`events`: [row, ...])."""
    candidates = []
    if isinstance(registry.get("rows"), dict):
        candidates = list(registry["rows"].values())
    elif isinstance(registry.get("events"), list):
        candidates = registry["events"]
    elif isinstance(registry, list):
        candidates = registry
    for row in candidates:
        if row.get("aliases", {}).get("catalog_event_id") == event_id:
            return row
    return None


def absolute_rows(rows):
    out = []
    for row in rows:
        out.append({
            "storage": row["storage"],
            "bank": int(row.get("bank", 0)),
            "index": int(row["index"]),
            "value": int(row["value"]),
        })
    return out


def effect_rows(rows):
    """`after` rows only: absolute writes tagged `write_legacy_value`, per
    the projection document's "Effects" section. Rows that are not effects
    (presets[].writes, terminals[].required_state, selected_by.conditions)
    stay plain, produced by absolute_rows instead."""
    out = []
    for row in rows:
        out.append({
            "type": "write_legacy_value",
            "storage": row["storage"],
            "bank": int(row.get("bank", 0)),
            "index": int(row["index"]),
            "value": int(row["value"]),
        })
    return out


def cell_key(row):
    return (row.get("storage"), int(row.get("bank", 0)), int(row.get("index", -1)))


def message_key(message):
    return (message["entry"], int(message["offset"]))


def longest_common_prefix(sequences):
    if not sequences:
        return []
    prefix = []
    for items in zip(*sequences):
        keys = {message_key(item) for item in items}
        if len(keys) != 1:
            break
        prefix.append(items[0])
    return prefix


def branch_matches_preset(branch, preset):
    """True when every condition row of the branch is satisfied by a write
    the preset makes (same storage/bank/index/value, operator "equals")."""
    for condition in branch.get("conditions", []):
        if condition.get("operator") != "equals":
            return False
        found = False
        for write in preset.get("writes", []):
            if (
                write["storage"] == condition["storage"]
                and int(write.get("bank", 0)) == int(condition.get("bank", 0))
                and int(write["index"]) == int(condition["index"])
                and int(write["value"]) == int(condition["value"])
            ):
                found = True
                break
        if not found:
            return False
    return True


def matched_branches(event, preset):
    """Branches (in the catalog row's own order) whose condition rows the
    preset's writes satisfy."""
    return [b for b in event.get("branches", []) if branch_matches_preset(b, preset)]


def build_condition_node_catalog(event, group, consumed, presets_by_id):
    """A node for one choice option's `group` of catalog runs, split by
    outcome signature (reusing the profile path's structural nesting
    helpers - `group_by_signature`, `_leaf`, `_node_shell`,
    `longest_common_prefix`): a leaf when it is already one signature, else
    a `results`-only (no `choice`) split, each sub-result labelled by the
    catalog `branches` rows its preset matched (as the no-choice path uses,
    via `matched_branches`) or, when the row declares no branches, that
    preset's own writes as equals conditions."""
    sig_groups, sig_order = group_by_signature(group)
    if len(sig_order) == 1:
        return _leaf(group, consumed)
    common_prefix = longest_common_prefix([c["messages"][consumed:] for c in group])
    new_consumed = consumed + len(common_prefix)
    node = _node_shell(group, common_prefix)
    sub_results = {}
    unresolved_index = 0
    for sig in sig_order:
        subgroup = sig_groups[sig]
        representative_preset = presets_by_id[subgroup[0]["preset_id"]]
        arms = matched_branches(event, representative_preset)
        sub_leaf = _leaf(subgroup, new_consumed)
        if arms:
            conditions_rows = []
            for branch in arms:
                for c in branch.get("conditions", []):
                    conditions_rows.append({
                        "storage": c["storage"], "bank": int(c.get("bank", 0)),
                        "index": int(c["index"]), "operator": c["operator"], "value": int(c["value"]),
                    })
            rid = ".".join(b["branch_id"] for b in arms)
        else:
            writes = absolute_rows(representative_preset.get("writes", []))
            conditions_rows = [
                {"storage": w["storage"], "bank": w["bank"], "index": w["index"], "operator": "equals", "value": w["value"]}
                for w in writes
            ]
            if writes:
                rid = condition_result_id([(w["storage"], w["bank"], w["index"], w["value"]) for w in writes])
            else:
                rid = "cond_unresolved_%d" % unresolved_index
                unresolved_index += 1
        sub_leaf["selected_by"] = {"kind": "condition", "conditions": conditions_rows}
        sub_results[rid] = sub_leaf
    node["results"] = sub_results
    return node


def load_events_document(package_dir, entry):
    stem = os.path.splitext(entry)[0].upper()
    path = os.path.join(package_dir, "events", "%s.json" % stem)
    return load_json(path)


def load_text_document(package_dir, entry):
    stem = os.path.splitext(entry)[0].upper()
    path = os.path.join(package_dir, "text", "%s.json" % stem)
    return load_json(path)


# ---------------------------------------------------------------------------
# TD-56 D11: call-argument storage is not an event effect
# ---------------------------------------------------------------------------
#
# Since Core 0.377.0 the runner models command `0x09` and token `0xF6` as one storage
# (`docs/spec/mes/format_and_method.md`, "Command 0x09 and token 0xF6 address one storage"), so
# a replay's `state_changes`/`state_diff` carry `global_i32` rows that are the arguments a
# caller hands a routine (selectors, ladder keys), not state an event sets for later. A
# projection tool decision (TD-56 D11, owner ruling 2026-10-11, not a native claim): a
# `global_i32` net change of a run is argument storage when the run executed a command-`0x09`
# record whose write range covers the index and whose literal equals the change's `after`
# (in a flow variant a covering record of an earlier hop counts too). It is left out of the
# effect derivation (no `after` row, no witness row) and recorded once per cell in
# `unresolved`; a `global_i32` change with no such record keeps the ordinary path. The test
# reads the v3 replays' `executed` offsets, so it is inert on a v2 replay (the frozen v4 to
# v6 producers' input).

ARGUMENT_STORAGE_LINE = ("argument storage: global_i32[%d] = %d written by command 0x09 at %s:%d; "
                         "not an event effect (TD-56 D11)")
_ARGUMENT_STORAGE_RE = re.compile(
    r"^argument storage: global_i32\[(\d+)\] = (-?\d+) written by command 0x09 at (.+):(\d+); "
    r"not an event effect \(TD-56 D11\)$")


def command_09_writes(document):
    """`{at: (start_slot, [literal value or None per written slot])}` for every command-`0x09`
    record (`argument_slot_write_run`, id 9) of one package member document; a library's
    records are inside its routines. A pair whose value is not a literal is `None`."""
    if document.get("kind") == "library":
        records = [r for routine in document.get("routines", []) for r in routine.get("records", [])]
    else:
        records = document.get("records", [])
    writes = {}
    for record in records:
        if record.get("op") != "argument_slot_write_run" or record.get("id") != 9:
            continue
        operands = record.get("operands") or []
        if len(operands) < 2 or "v" not in operands[0]:
            continue
        values = []
        for pair in operands[1].get("pairs", []) or []:
            ast = pair.get("ast")
            values.append(int(ast["value"]) if isinstance(ast, dict) and ast.get("type") == "literal" else None)
        writes[int(record["at"])] = (int(operands[0]["v"]), values)
    return writes


class ArgumentStorage:
    """The D11 rule for one document: `split` takes a run's net changes and the `executed`
    maps of the runs that may have written them, returns the changes that are not argument
    storage, and remembers the others; `lines` is the document's `unresolved` record of them,
    once per `(index, value)` with the smallest `(entry, offset)` of the covering records."""

    def __init__(self, load_document):
        self._load_document = load_document
        self._writes = {}
        self.writers = {}

    def _writes_of(self, entry):
        if entry not in self._writes:
            self._writes[entry] = command_09_writes(self._load_document(entry))
        return self._writes[entry]

    def writer(self, executed_runs, index, value):
        """The smallest `(entry, at)` of a command-`0x09` record, executed in one of
        `executed_runs` (maps of entry to offsets), whose range covers `index` with the
        literal `value`; None when there is none."""
        best = None
        for executed in executed_runs:
            for entry, offsets in (executed or {}).items():
                writes = self._writes_of(entry)
                for at in offsets:
                    write = writes.get(at)
                    if write is None:
                        continue
                    start, values = write
                    if start <= index < start + len(values) and values[index - start] == value:
                        if best is None or (entry, at) < best:
                            best = (entry, at)
        return best

    def split(self, net_changes, executed_runs):
        """`net_changes` (`{(storage, bank, index): {..., "before", "after"}}`) without the
        argument-storage changes."""
        if not any(key[0] == "global_i32" for key in net_changes):
            return net_changes
        kept = {}
        for key, change in net_changes.items():
            if key[0] == "global_i32":
                found = self.writer(executed_runs, key[2], int(change["after"]))
                if found is not None:
                    pair = (key[2], int(change["after"]))
                    if pair not in self.writers or found < self.writers[pair]:
                        self.writers[pair] = found
                    continue
            kept[key] = change
        return kept

    def lines(self):
        return [ARGUMENT_STORAGE_LINE % (index, value, entry, at)
                for (index, value), (entry, at) in sorted(self.writers.items())]


def merge_unresolved(lines):
    """`lines` without duplicates, in first-seen order, with the D11 lines of one
    `(index, value)` collapsed to the one naming the smallest `(entry, offset)`, so a
    document that derives argument storage on more than one path lists a cell once."""
    best = {}
    for line in lines:
        match = _ARGUMENT_STORAGE_RE.match(line)
        if match:
            pair = (int(match.group(1)), int(match.group(2)))
            writer = (match.group(3), int(match.group(4)))
            if pair not in best or writer < best[pair]:
                best[pair] = writer
    out = []
    seen = set()
    for line in lines:
        match = _ARGUMENT_STORAGE_RE.match(line)
        if match:
            pair = (int(match.group(1)), int(match.group(2)))
            line = ARGUMENT_STORAGE_LINE % (pair[0], pair[1], best[pair][0], best[pair][1])
        if line not in seen:
            seen.add(line)
            out.append(line)
    return out


def build_dialogue_entry(message, events_doc_by_entry, report):
    """Builds one `{"kind": "text", "text_ref": {...}}` or `{"kind":
    "name_insert", ...}` dialogue entry for a replayed message. Returns
    None (and records a fatal report entry) when a record that should be a
    text record has no resolvable text operand - the caller must stop."""
    entry = message["entry"]
    offset = int(message["offset"])
    events_doc = events_doc_by_entry[entry]
    record = None
    for candidate in events_doc["records"]:
        if int(candidate["at"]) == offset:
            record = candidate
            break
    if record is None:
        report["missing_records"].append({"entry": entry, "at": offset})
        return None
    op = record.get("op", "")
    if op == "protagonist_name_insert":
        return {
            "kind": "name_insert",
            "entry": entry,
            "at": offset,
            "raw_sha256": message["raw_sha256"],
        }
    operands = record.get("operands", [])
    if operands and operands[0].get("t") == "text" and "s" in operands[0]:
        return {
            "kind": "text",
            "text_ref": {
                "entry": entry,
                "at": offset,
                "s": int(operands[0]["s"]),
                "raw_sha256": message["raw_sha256"],
            },
        }
    # A text record whose operand is genuinely missing: fatal.
    report["missing_text_operand"].append({"entry": entry, "at": offset, "op": op})
    return None


def build_dialogue_list(messages, events_doc_by_entry, report):
    entries = []
    for message in messages:
        entry = build_dialogue_entry(message, events_doc_by_entry, report)
        if entry is None:
            return None
        entries.append(entry)
    return entries


def run_catalog(args):
    catalog = load_json(args.catalog)
    event = find_event(catalog, args.event)
    if event is None:
        print("EVENT NOT FOUND: %s" % args.event)
        return 1

    registry, names_fingerprint = load_registry(args.names)
    row = find_registry_row(registry, args.event)
    if row is None:
        print("REGISTRY ROW NOT FOUND for %s" % args.event)
        return 1
    if names_fingerprint == "unrecorded":
        print("names_fingerprint: unrecorded (registry at %s has no names_fingerprint file)" % args.names)
    else:
        print("names_fingerprint=%s" % names_fingerprint)

    manifest = load_json(os.path.join(args.package, "manifest.json"))
    replay = load_json(args.replay)

    if replay["archive_sha256"] != manifest["source"]["archive_sha256"]:
        print("ARCHIVE MISMATCH between replay and package manifest")
        return 1

    report = {"missing_records": [], "missing_text_operand": []}

    # --- id / display -------------------------------------------------
    doc_id = row["id"]
    display = {
        "title_ko": row.get("title_ko", ""),
        "title_en": row.get("title_en", ""),
        "heroine": row.get("heroine", ""),
        "category": row.get("category", ""),
        "place": row.get("place", ""),
    }

    # --- evidence -------------------------------------------------------
    callee = event["source"]["callee"]
    caller = event["source"]["caller"]
    # EVENTD05/EVENTD06 declare no presets: the replay CLI runs one
    # synthetic "baseline" preset (writes=[]) for them; key by it the same
    # way here.
    event_presets = event.get("presets") or [{"preset_id": "baseline", "label": "baseline", "writes": []}]
    members = [{"entry": callee["entry"], "entry_sha256": callee["entry_sha256"]}]
    for required in event["source"].get("required_entries", []):
        members.append({"entry": required["entry"], "entry_sha256": required["entry_sha256"]})

    evidence = {
        "kind": "catalog_event",
        "archive_sha256": replay["archive_sha256"],
        "catalog_id": catalog["catalog_id"],
        "catalog_revision": catalog["catalog_revision"],
        "groups": [],
        "members": members,
        "document_refs": event.get("activation", {}).get("document_refs", []),
    }

    package_binding = {"schema": manifest["schema"], "package_sha256": manifest["package_sha256"]}

    # Most catalog rows record no analysis_route (only EVENTJ04 does today):
    # the caller prefix was never replayed for them (replay_event_dialogue.gd
    # skips it and marks caller_prefix_replayed false), so the origin falls
    # back to the dispatch record itself.
    catalog_extra_unresolved = []
    if "analysis_route" in event:
        origin_offset = int(event["analysis_route"]["caller_start_coordinate"])
    else:
        origin_offset = int(event["source"]["caller"]["dispatch_offset"])
        catalog_extra_unresolved.append(
            "no analysis route recorded in the catalog: the caller prefix was not replayed; "
            "origin is the dispatch record itself"
        )

    trigger = {
        "type": "caller_dispatch",
        "caller": {
            "entry": caller["entry"],
            "entry_sha256": caller["entry_sha256"],
            "offset": int(caller["dispatch_offset"]),
            "end": int(caller["resume_offset"]),
            "command": int(caller["command"]),
            "kind": "root_handoff" if int(caller["command"]) == 14 else "nested_call",
        },
        "callee": {
            "entry": callee["entry"],
            "entry_sha256": callee["entry_sha256"],
            "start_coordinate": int(callee["start_coordinate"]),
        },
        "origin": {"kind": "caller_prefix", "offset": origin_offset},
    }

    choices = event.get("choices", [])
    if len(choices) > 1:
        print("MULTIPLE CHOICE ROWS not supported: %s" % [c.get("choice_id") for c in choices])
        return 1
    kind = "choice_event" if choices else "event"

    # --- conditions: event_not_completed --------------------------------
    # EVENTJ04's single terminal requires global_u8[905]=1 (with 854, 927,
    # 3714, 286) after completion. 905 is chosen as the done flag: it is
    # the first-listed required_state cell and the reentry run (state
    # carrying all five =1) returns immediately with zero messages, so a
    # gate on this cell alone already reproduces "already completed". The
    # choice is recorded explicitly as `conditions[0].done_cell`.
    done_flag = None
    for terminal in event.get("terminals", []):
        for req in terminal.get("required_state", []):
            if req.get("operator") == "equals" and int(req.get("value", -1)) == 1:
                done_flag = req
                break
        if done_flag:
            break
    conditions = []
    if done_flag is not None:
        conditions.append({
            "type": "event_not_completed",
            "event_id": doc_id,
            "failure_reason": "already_completed",
            "done_cell": {
                "storage": done_flag["storage"],
                "bank": int(done_flag.get("bank", 0)),
                "index": int(done_flag["index"]),
                "value": int(done_flag["value"]),
            },
        })

    # --- presets ---------------------------------------------------------
    presets = []
    presets_by_id = {}
    for preset in event_presets:
        presets_by_id[preset["preset_id"]] = preset
        presets.append({
            "preset_id": preset["preset_id"],
            "label": preset.get("label", ""),
            "writes": absolute_rows(preset["writes"]),
        })

    # --- replay runs indexed by preset -----------------------------------
    runs_by_preset = {}
    for run in replay["runs"]:
        runs_by_preset[run["preset_id"]] = run

    all_message_lists = [run["messages"] for run in replay["runs"]]
    body_messages = longest_common_prefix(all_message_lists)

    # --- terminals ---------------------------------------------------------
    terminals = {}
    terminal_id_by_offset = {}
    terminal_kind_mappings_used = set()
    for terminal in event.get("terminals", []):
        v3_kind = catalog_terminal_kind(terminal)
        if not (terminal["kind"] == "root_replacement" and v3_kind == "root_handoff"):
            terminal_kind_mappings_used.add((terminal["kind"], v3_kind))
        terminals[terminal["terminal_id"]] = {
            "kind": v3_kind,
            "owner_entry": terminal["owner_entry"],
            "offset": int(terminal["offset"]),
            "end": int(terminal["caller_resume_offset"]),
            "next_target": terminal.get("next_target", ""),
            "required_state": absolute_rows([
                {"storage": r["storage"], "bank": r.get("bank", 0), "index": r["index"], "value": r["value"]}
                for r in terminal.get("required_state", [])
            ]),
        }
        terminal_id_by_offset[int(terminal["offset"])] = terminal["terminal_id"]
    if terminal_kind_mappings_used:
        mapping_list = ", ".join("%s -> %s" % pair for pair in sorted(terminal_kind_mappings_used))
        catalog_extra_unresolved.append("catalog terminal kinds mapped to v3: %s" % mapping_list)

    # Body-level `after`: effects shared by every result. EVENTJ04 has one
    # terminal shared by every run, so its required_state rows are exactly
    # what every result shares; each result's own `after` is the rest,
    # which is empty here.
    single_terminal_required_state = None
    if len(event.get("terminals", [])) == 1:
        single_terminal_required_state = terminals[event["terminals"][0]["terminal_id"]]["required_state"]
    body_after = effect_rows(single_terminal_required_state) if single_terminal_required_state else []

    # --- text resolution setup --------------------------------------------
    events_doc_by_entry = {}
    involved_entries = {callee["entry"]}
    for run in replay["runs"]:
        for message in run["messages"]:
            involved_entries.add(message["entry"])
    for entry in involved_entries:
        events_doc_by_entry[entry] = load_events_document(args.package, entry)

    body_dialogue = build_dialogue_list(body_messages, events_doc_by_entry, report)
    if body_dialogue is None:
        print("FATAL missing_text_operand in the body: %s" % report["missing_text_operand"])
        return 1

    # --- results: one per distinct replayed outcome -----------------------
    document_choice = None
    if choices:
        # The replay runs are keyed by (preset_id, option): rebuild the
        # per-run pool directly from replay["runs"] instead of
        # runs_by_preset (which only ever keeps the last option's run for a
        # given preset - harmless for the no-choice path below, where every
        # preset has exactly one run, but not here).
        choice_row = choices[0]
        owner = "callee" if choice_row["owner_entry"] == callee["entry"] else "caller"
        body_len = len(body_messages)

        candidates = []
        for run in replay["runs"]:
            option = run.get("option")
            option_int = int(option) if option is not None else None
            candidates.append({
                "preset_id": run["preset_id"], "option": option_int,
                "route_id": run["preset_id"],
                "variant_id": ("option%d" % option_int) if option_int is not None else run["preset_id"],
                "messages": run["messages"], "run": run,
                "terminal_sig": (
                    run["terminal"]["entry"], run["terminal"]["status"],
                    int(run["terminal"]["offset"]), run["terminal"].get("target", ""),
                ),
            })

        def resolve_catalog_node(result_id, node):
            rep_run = node["representative"]["run"]
            dialogue = build_dialogue_list(node["dialogue_messages"], events_doc_by_entry, report)
            if dialogue is None:
                return None
            terminal_offset = int(rep_run["terminal"].get("offset", -1))
            reentry_source = rep_run.get("reentry")
            reentry = None
            if reentry_source is not None:
                reentry = {
                    "kind": "callee_return",
                    "message_count": int(reentry_source["message_count"]),
                    "effects": [],
                }
            resolved = {
                "selected_by": node["selected_by"],
                "event_played": node["event_played"],
                "dialogue": dialogue,
                "after": [],
                "terminal": terminal_id_by_offset.get(terminal_offset),
                "reentry": reentry,
            }
            if node.get("results") is not None:
                sub_results = {}
                for sub_id, sub_node in node["results"].items():
                    sub_resolved = resolve_catalog_node(sub_id, sub_node)
                    if sub_resolved is None:
                        return None
                    sub_results[sub_id] = sub_resolved
                resolved["results"] = sub_results
            return resolved

        results = {}
        option_values = sorted({c["option"] for c in candidates if c["option"] is not None})
        try:
            for value in option_values:
                group = [c for c in candidates if c["option"] == value]
                node = build_condition_node_catalog(event, group, body_len, presets_by_id)
                node["selected_by"] = {"kind": "choice", "value": value}
                resolved = resolve_catalog_node("answer%d" % value, node)
                if resolved is None:
                    print("FATAL missing_text_operand in result answer%d: %s" % (value, report["missing_text_operand"]))
                    return 1
                results["answer%d" % value] = resolved
        except ReproductionMismatch as exc:
            print("REPRODUCTION MISMATCH: %s" % exc)
            return 1

        document_choice = {
            "owner": owner,
            "boundary": int(choice_row["boundary_offset"]),
            "position": "in_event" if owner == "callee" else "before_event",
            "options": [{"value": v, "result": "answer%d" % v} for v in option_values],
        }
    else:
        # Group presets by outcome signature (message sequence by entry+offset,
        # the run's effect rows, the terminal). For J04 the four presets give
        # four distinct signatures, so four results, one per run.
        groups = {}
        group_order = []
        for preset in event_presets:
            preset_id = preset["preset_id"]
            run = runs_by_preset.get(preset_id)
            if run is None:
                continue
            msg_keys = tuple(message_key(m) for m in run["messages"])
            terminal_sig = (
                run["terminal"].get("offset"), run["terminal"].get("end"),
                run["terminal"].get("target"), run["terminal"].get("status"),
            )
            effect_sig = tuple(sorted(
                (cell_key(row), row["value"]) for row in run.get("final_state", [])
            ))
            signature = (msg_keys, effect_sig, terminal_sig)
            groups.setdefault(signature, []).append(preset_id)
            if signature not in group_order:
                group_order.append(signature)

        results = {}
        for signature in group_order:
            preset_ids = groups[signature]
            representative_id = preset_ids[0]
            representative_run = runs_by_preset[representative_id]
            representative_preset = presets_by_id[representative_id]
            arms = matched_branches(event, representative_preset)
            result_id = ".".join(b["branch_id"] for b in arms) if arms else representative_id

            run_messages = representative_run["messages"]
            body_len = len(body_messages)
            if [message_key(m) for m in run_messages[:body_len]] != [message_key(m) for m in body_messages]:
                print("BODY PREFIX MISMATCH for %s" % result_id)
                return 1
            remainder = run_messages[body_len:]
            result_dialogue = build_dialogue_list(remainder, events_doc_by_entry, report)
            if result_dialogue is None:
                print("FATAL missing_text_operand in result %s: %s" % (result_id, report["missing_text_operand"]))
                return 1

            # Assert reproduction: body + result dialogue == the run's own
            # message list, exactly, in order.
            reproduced_keys = [message_key(m) for m in body_messages] + [message_key(m) for m in remainder]
            run_keys = [message_key(m) for m in run_messages]
            if reproduced_keys != run_keys:
                print("REPRODUCTION MISMATCH for %s" % result_id)
                return 1

            conditions_rows = []
            for branch in arms:
                for c in branch.get("conditions", []):
                    conditions_rows.append({
                        "storage": c["storage"], "bank": int(c.get("bank", 0)),
                        "index": int(c["index"]), "operator": c["operator"], "value": int(c["value"]),
                    })

            terminal_offset = int(representative_run["terminal"].get("offset", -1))
            terminal_id = terminal_id_by_offset.get(terminal_offset)

            reentry_source = representative_run.get("reentry")
            reentry = None
            if reentry_source is not None:
                reentry = {
                    "kind": "callee_return",
                    "message_count": int(reentry_source["message_count"]),
                    "effects": [],
                }

            results[result_id] = {
                "selected_by": {"kind": "condition", "conditions": conditions_rows},
                "event_played": True,
                "dialogue": result_dialogue,
                "after": [],
                "terminal": terminal_id,
                "reentry": reentry,
                "_presets": preset_ids,  # diagnostic only, stripped before writing
                "_body_len": body_len,
                "_total_len": len(run_messages),
            }

    # --- dependencies / presentation / unresolved --------------------------
    dependencies = []
    for required in event["source"].get("required_entries", []):
        dependencies.append({
            "entry": required["entry"],
            "entry_sha256": required["entry_sha256"],
            "role": required.get("role", ""),
        })

    presentation = {"status": "deferred", "resources": event.get("resources", [])}
    unresolved = [blocker["summary"] for blocker in event.get("blockers", [])] + catalog_extra_unresolved

    # Strip diagnostic-only keys before writing the tracked document (the
    # no-choice path only - the choice path never adds them).
    result_counts = {}
    if not choices:
        for result_id, result in results.items():
            result_counts[result_id] = (result.pop("_presets"), result.pop("_body_len"), result.pop("_total_len"))

    document = {
        "schema_version": SCHEMA_VERSION,
        "contract_fingerprint": resolve_contract_fingerprint(args.contract_fingerprint),
        "names_fingerprint": names_fingerprint,
        "id": doc_id,
        "kind": kind,
        "display": display,
        "evidence": evidence,
        "package_binding": package_binding,
        "trigger": trigger,
        "scenes": [],
        "guard": None,
        "conditions": conditions,
        "presets": presets,
        "dialogue": body_dialogue,
        "after": body_after,
        "results": results,
        "terminals": terminals,
        "dependencies": dependencies,
        "presentation": presentation,
        "unresolved": unresolved,
    }
    if document_choice is not None:
        document["choice"] = document_choice

    if document["contract_fingerprint"] == "unrecorded" and not args.allow_unrecorded:
        print("contract_fingerprint is 'unrecorded' (part 3 has not recorded it yet); writing anyway per task instructions.")

    os.makedirs(args.out, exist_ok=True)
    tracked_path = os.path.join(args.out, "%s.json" % doc_id)
    with open(tracked_path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(document, fh, indent=2, ensure_ascii=False, sort_keys=False)
        fh.write("\n")

    # --- resolved document ---------------------------------------------
    text_doc_by_entry = {}
    for entry in involved_entries:
        text_doc_by_entry[entry] = load_text_document(args.package, entry)

    def resolve_dialogue_entry(entry):
        resolved = json.loads(json.dumps(entry))
        if resolved.get("kind") == "text":
            text_ref = resolved["text_ref"]
            strings = text_doc_by_entry[text_ref["entry"]]["strings"]
            text_ref["text"] = strings[text_ref["s"]]
        return resolved

    def dialogue_script(dialogue_entries):
        lines = []
        for entry in dialogue_entries:
            if entry.get("kind") == "text":
                text_ref = entry["text_ref"]
                strings = text_doc_by_entry[text_ref["entry"]]["strings"]
                text = strings[text_ref["s"]]
                lines.append("-: %s" % text)
            elif entry.get("kind") == "name_insert":
                lines.append("-: {name}")
        return lines

    def resolve_result_tree(result_id, result_node):
        resolved = dict(result_node)
        resolved["dialogue"] = [resolve_dialogue_entry(e) for e in result_node["dialogue"]]
        script_lines = ["[result %s]" % result_id]
        script_lines.extend(dialogue_script(result_node["dialogue"]))
        script_lines.append("[terminal %s]" % result_node["terminal"])
        if result_node.get("results"):
            resolved["results"] = {}
            for sub_id, sub_node in result_node["results"].items():
                resolved["results"][sub_id] = resolve_result_tree(sub_id, sub_node)
                script_lines.extend(resolved["results"][sub_id]["script"])
        resolved["script"] = script_lines
        return resolved

    resolved_document = json.loads(json.dumps(document))
    resolved_document["dialogue"] = [resolve_dialogue_entry(e) for e in body_dialogue]
    resolved_document["script"] = dialogue_script(body_dialogue)
    resolved_document["results"] = {result_id: resolve_result_tree(result_id, result) for result_id, result in results.items()}

    resolved_dir = args.resolved_out or args.out
    os.makedirs(resolved_dir, exist_ok=True)
    resolved_path = os.path.join(resolved_dir, "%s.resolved.json" % doc_id)
    with open(resolved_path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(resolved_document, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    # --- summary (no text) -----------------------------------------------
    print("PROJECTED %s" % doc_id)
    print("body_messages=%d" % len(body_dialogue))
    if choices:
        def count_catalog_messages(result):
            total = len(result["dialogue"])
            for sub in (result.get("results") or {}).values():
                total += count_catalog_messages(sub)
            return total

        def count_catalog_results(results_dict):
            total = 0
            for sub in results_dict.values():
                total += 1
                if sub.get("results"):
                    total += count_catalog_results(sub["results"])
            return total

        for result_id, result in results.items():
            print("result %s messages=%d terminal=%s" % (
                result_id, count_catalog_messages(result), result["terminal"],
            ))
        print("results=%d terminals=%d" % (count_catalog_results(results), len(terminals)))
    else:
        for result_id, result in results.items():
            presets_for_result, body_len, total_len = result_counts[result_id]
            print("result %s presets=%s messages=%d body+dialogue=%d terminal=%s" % (
                result_id, presets_for_result, len(result["dialogue"]),
                body_len + len(result["dialogue"]), result["terminal"],
            ))
        print("results=%d terminals=%d" % (len(results), len(terminals)))
    if report["missing_records"]:
        print("UNRESOLVED missing_records=%s" % [
            "%s@%d" % (r["entry"], r["at"]) for r in report["missing_records"]
        ])
    if report["missing_text_operand"]:
        print("UNRESOLVED missing_text_operand=%s" % [
            "%s@%d(%s)" % (r["entry"], r["at"], r["op"]) for r in report["missing_text_operand"]
        ])
    print("WROTE %s" % tracked_path)
    print("WROTE %s" % resolved_path)
    return 0


# ============================================================================
# Site path (part B): projects a profile-declared event site (`--site`).
# ============================================================================


def _simple(ast: dict) -> tuple | None:
    """(storage, index, op, literal) for `cell OP literal` / `literal OP cell`,
    else None. Copied from tools/draft_event_route_spec.py (not imported)."""
    if not isinstance(ast, dict) or ast.get("type") != "binary":
        return None
    lhs, rhs, op = ast.get("lhs"), ast.get("rhs"), ast.get("op")
    flip = {"greater_than": "less_than", "less_than": "greater_than", "equal": "equal", "not_equal": "not_equal"}

    def cell(node):
        if isinstance(node, dict) and node.get("type") == "state_ref":
            index = node.get("index")
            if isinstance(index, dict) and index.get("type") == "literal":
                index = index.get("value")
            if not isinstance(index, dict):
                return node.get("storage"), int(index)
        return None

    def literal(node):
        return node.get("value") if isinstance(node, dict) and node.get("type") == "literal" else None
    if cell(lhs) is not None and literal(rhs) is not None:
        return (*cell(lhs), op, int(literal(rhs)))
    if cell(rhs) is not None and literal(lhs) is not None and op in flip:
        return (*cell(rhs), flip[op], int(literal(lhs)))
    return None


# The producer cannot verify a banked_u16 index -> heroine-letter table: the
# two sources the spec names, docs/spec/mes/duplicate_entries.md (entry file
# -> letter -> gallery scene count only) and the drafter's own
# tools/draft_event_route_spec.py:_cell_name (labels every banked_u16
# affection-range cell "wordNNN", not by letter), neither carries one. Guard
# conjuncts on banked_u16[200..215] are therefore emitted as `cell`, never
# `affection`; AFFECTION_HEROINE_LETTERS stays None in production and is
# exercised only by the unit tests, which supply their own synthetic table.
AFFECTION_HEROINE_LETTERS = None


def guard_conjunct_kind(storage, index):
    if storage == "state_u16" and index == 4:
        return "weekday"
    if storage == "state_u16" and index == 7:
        return "date"
    if storage == "state_u16" and index == 19:
        return "clock"
    if storage == "state_u16" and index == 21:
        return "choice"
    if storage == "banked_u16" and 200 <= index <= 215:
        return "affection"
    return "cell"


def map_conjunct(part, affection_letters=None):
    """One v3 guard-conjunct row for `part` (`{"text", "cells", "ast"}`, as
    `mes_route_decode.conjuncts` returns one top-level `and` part)."""
    simple = _simple(part["ast"])
    if simple is None:
        return {"kind": "mes_expression", "ast": part["ast"]}
    storage, index, op, value = simple
    kind = guard_conjunct_kind(storage, index)
    if kind == "affection":
        letter = (affection_letters or {}).get(index)
        if letter is None:
            kind = "cell"
        else:
            return {"kind": "affection", "heroine": letter, "op": op, "value": int(value)}
    if kind == "cell":
        return {"kind": "cell", "storage": storage, "bank": 0, "index": index, "op": op, "value": int(value)}
    return {"kind": kind, "op": op, "value": int(value)}


def guard_ast(archive, entry, branch_offset):
    """The whole condition AST of the `branch_if_not_true` at `branch_offset`
    (the same extraction `mes_route_decode.conjuncts` does, without splitting
    the top-level `and` into parts)."""
    for instruction in archive.instructions(entry):
        if int(instruction["source_offset"]) != branch_offset or instruction.get("op") != "branch_if_not_true":
            continue
        operands = instruction.get("operands") or []
        condition = next((o["value"] for o in operands if o.get("type") == "condition"), {})
        return condition.get("ast", condition)
    raise KeyError("no branch at %s:%d" % (entry, branch_offset))


def find_done_cell(conjunct_rows, route):
    """Rule B: the guard's cleared-flag `global_u8` conjunct (`op: equal`,
    `value: 0`) whose index the route's own `expected_state` (or every one
    of its variants') sets to 1 - the flag the event's own completion sets,
    matched against the guard condition that keeps a completed event from
    re-triggering. Returns the index, or None when no such conjunct/cell
    pairing exists."""
    ones = {
        int(row["index"]) for row in (route.get("expected_state", []) or [])
        if row["storage"] == "global_u8" and int(row["value"]) == 1
    }
    variants = route.get("variants", []) or []
    if variants:
        variant_ones = None
        for variant in variants:
            this_variant_ones = {
                int(row["index"]) for row in (variant.get("expected_state", []) or [])
                if row["storage"] == "global_u8" and int(row["value"]) == 1
            }
            variant_ones = this_variant_ones if variant_ones is None else (variant_ones & this_variant_ones)
        ones |= (variant_ones or set())
    for row in conjunct_rows:
        if (row.get("kind") == "cell" and row.get("storage") == "global_u8"
                and row.get("op") == "equal" and int(row.get("value", -1)) == 0):
            index = int(row["index"])
            if index in ones:
                return index
    return None


def schema_version_number(schema):
    match = re.search(r"/v(\d+)$", schema or "")
    return int(match.group(1)) if match else -1


def find_registry_row_by_id(registry, site_id):
    candidates = []
    if isinstance(registry.get("rows"), dict):
        candidates = list(registry["rows"].values())
    elif isinstance(registry.get("events"), list):
        candidates = registry["events"]
    elif isinstance(registry, list):
        candidates = registry
    for row in candidates:
        if row.get("id") == site_id:
            return row
    return None


def load_profiles(profiles_dir):
    profiles = {}
    for name in sorted(os.listdir(profiles_dir)):
        if not name.endswith(".json"):
            continue
        stem = name[: -len(".json")]
        profiles[stem] = load_json(os.path.join(profiles_dir, name))
    return profiles


def resolve_site(row, profiles):
    """`[{"stem", "doc", "group_id", "routes": [matched route dicts]}, ...]`
    for every profile declaring the site named by `row`, sorted by stem."""
    alias_groups = {g["group_id"]: set(g.get("route_ids", [])) for g in row.get("aliases", {}).get("groups", [])}
    evidence = row["evidence"]
    matches = []
    for stem, doc in profiles.items():
        group_id = doc.get("group_id")
        if group_id not in alias_groups:
            continue
        allowed_route_ids = alias_groups[group_id]
        matched_routes = []
        for route in doc.get("routes", []):
            if route["route_id"] not in allowed_route_ids:
                continue
            # EP-12 / WD unit 2 (2026-09-25): a `kakyu_event_analysis_group/v14`
            # flow route carries no `caller`/`callee` pair (its own shape is
            # `origin`/`hops`/`terminal`; `docs/spec/data/event_definition_v6.md`).
            # A registry row naming a flow route's own group (the three
            # `01m-a-date` sites) is resolved by `project_event_definition_v6.py`'s
            # own flow dispatch, never through this v3/v4/v5 site-evidence
            # path; skipping a caller/callee-less route here (rather than a
            # `KeyError`) keeps every other row's own scan over a shared
            # caller (`compute_order_hint`) from crashing when a sibling flow
            # route happens to share its group.
            if "caller" not in route or "callee" not in route:
                continue
            if route["caller"]["entry"] != evidence["caller"]:
                continue
            if route["callee"]["entry"] != evidence["callee"]:
                continue
            if int(route["caller"]["offset"]) != int(evidence["dispatch_offset"]):
                continue
            matched_routes.append(route)
        if matched_routes:
            matches.append({"stem": stem, "doc": doc, "group_id": group_id, "routes": matched_routes})
    matches.sort(key=lambda m: m["stem"])
    return matches


def choose_preferred(matches):
    """The profile whose matched routes carry `map_location_contracts`; if
    none or several do, the one with the highest schema version number;
    ties by file stem."""
    with_map = [m for m in matches if any(r.get("map_location_contracts") for r in m["routes"])]
    if len(with_map) == 1:
        return with_map[0]
    pool = matches
    best_version = max(schema_version_number(m["doc"].get("schema")) for m in pool)
    tied = sorted((m for m in pool if schema_version_number(m["doc"].get("schema")) == best_version),
                  key=lambda m: m["stem"])
    return tied[0]


def contract_owner(contract, route):
    """"caller" when `contract`'s boundary_offset lies in the caller's code:
    directly from the contract's own `source_identity.entry` (every
    choice_contract in the analysis groups carries one); a variant's
    `selections` row naming the boundary's owner_entry is the fallback for a
    contract that does not (none do today, but `selections` is what the
    field-mapping doc names)."""
    caller_entry = route["caller"]["entry"]
    source_entry = (contract.get("source_identity") or {}).get("entry")
    if source_entry is not None:
        return "caller" if source_entry == caller_entry else "callee"
    boundary = int(contract["boundary_offset"])
    for variant in route.get("variants", []):
        for sel in variant.get("selections") or []:
            if int(sel["boundary_offset"]) == boundary and "owner_entry" in sel:
                return "caller" if sel["owner_entry"] == caller_entry else "callee"
    return "callee"


def choose_contracts(route):
    """(top_contract, second_contract) from `route["choice_contracts"]`: the
    caller-owned one is the top-level contract; failing that, the one with
    the smallest boundary_offset. `second_contract` is the remaining
    contract with the smallest boundary_offset, or None."""
    contracts = route.get("choice_contracts") or []
    if not contracts:
        return None, None
    top = None
    for c in contracts:
        if contract_owner(c, route) == "caller":
            top = c
            break
    if top is None:
        top = min(contracts, key=lambda c: int(c["boundary_offset"]))
    remaining = [c for c in contracts if c is not top]
    second = min(remaining, key=lambda c: int(c["boundary_offset"])) if remaining else None
    return top, second


def build_candidate(route, variant, replay_variant):
    """One (route, variant) candidate for results grouping. `messages` and
    `terminal_sig` make up the outcome signature (Rule A: the entry-state
    dependent absolute values in `final_state` do not - they multiplied
    results on real profiles, e.g. a counter that keeps climbing across
    presentation-only edge variants). `declared_keys` (this variant's own
    `expected_state` cell keys) and `full_state` (every cell the replay
    recorded) are kept for the group-level `after`/`unresolved` computation
    in `group_after_effects`, not for the signature."""
    declared_keys = {
        (row["storage"], int(row.get("bank", 0)), int(row["index"]))
        for row in (variant.get("expected_state", []) or [])
    }
    full_state = {}
    for row in replay_variant.get("final_state", []) or []:
        key = (row["storage"], int(row.get("bank", 0)), int(row["index"]))
        full_state[key] = int(row["value"])
    terminal = replay_variant["terminal"]
    terminal_sig = (terminal["entry"], terminal["status"], int(terminal["offset"]), terminal.get("target", ""))
    selections = {}
    for row in replay_variant.get("selections") or []:
        selections[int(row["boundary_offset"])] = int(row["result_value"])
    writes = [
        {"storage": w["storage"], "bank": int(w.get("bank", 0)), "index": int(w["index"]), "value": int(w["value"])}
        for w in (variant.get("writes") or [])
    ]
    return {
        "route_id": route["route_id"], "variant_id": variant["variant_id"],
        "route": route, "variant": variant,
        "messages": list(replay_variant.get("messages") or []),
        "declared_keys": declared_keys,
        "full_state": full_state,
        "terminal_sig": terminal_sig,
        "selections": selections,
        "writes": writes,
        "is_baseline": not writes,
    }


def candidate_signature(candidate):
    """Rule A: the message sequence and the callee terminal only."""
    return (
        tuple(message_key(m) for m in candidate["messages"]),
        candidate["terminal_sig"],
    )


def group_by_signature(candidates):
    groups = {}
    order = []
    for c in candidates:
        sig = candidate_signature(c)
        if sig not in groups:
            groups[sig] = []
            order.append(sig)
        groups[sig].append(c)
    return groups, order


def partition_by_boundary(candidates, boundary_offset):
    """Groups `candidates` by their selection value at `boundary_offset`. A
    candidate with no selection for it takes the value a sibling of the same
    route carries (a route's variants all declare the same selections)."""
    groups = {}
    order = []
    for c in candidates:
        value = c["selections"].get(boundary_offset)
        if value is None:
            for sibling in candidates:
                if sibling["route_id"] == c["route_id"] and boundary_offset in sibling["selections"]:
                    value = sibling["selections"][boundary_offset]
                    break
        groups.setdefault(value, []).append(c)
        if value not in order:
            order.append(value)
    return groups, order


def _write_set(candidate):
    return set((w["storage"], w["bank"], w["index"], w["value"]) for w in candidate["writes"])


def distinguishing_writes(group, other_candidates):
    """Rule A `selected_by`: (storage, bank, index, value) tuples present in
    every candidate's own `writes` (a variant's delta from its route's
    baseline) in `group`, AND absent from every candidate's `writes` outside
    it - so the condition actually distinguishes this group from its
    siblings, not just from a coincidentally write-less member of its own
    group. Empty when any candidate in `group` (e.g. the baseline variant)
    has no writes, or when nothing in the group's common writes is unique
    to it."""
    if not group:
        return []
    sets = [_write_set(c) for c in group]
    common = set.intersection(*sets)
    if not common:
        return []
    other_writes = set()
    for c in other_candidates:
        other_writes |= _write_set(c)
    return sorted(common - other_writes)


def group_after_effects(group, body_after_keys, unresolved):
    """Rule A `after`: a cell any candidate in `group` declares in its own
    `expected_state` becomes an absolute `after` row when every candidate in
    the group agrees on its replayed final value (and the cell is not
    already in the body `after`); when the group's candidates disagree on
    that cell's final value, no effect is written for it - one line is
    appended to `unresolved` instead, naming the cell and the distinct
    observed values (deduped later at the document level)."""
    keys_of_interest = set()
    for c in group:
        keys_of_interest |= c["declared_keys"]
    after_rows = []
    for key in sorted(keys_of_interest):
        if key in body_after_keys:
            continue
        storage, bank, index = key
        values = sorted({c["full_state"][key] for c in group if key in c["full_state"]})
        if not values:
            continue
        if len(values) == 1:
            after_rows.append({
                "type": "write_legacy_value", "storage": storage, "bank": bank, "index": index,
                "value": values[0],
            })
        else:
            unresolved.append(
                "effect on %s[%d] depends on the entry state (observed final values %s); "
                "v3 has no delta effect" % (storage, index, values)
            )
    return after_rows


def condition_rows(common):
    return [
        {"storage": storage, "bank": bank, "index": index, "operator": "equals", "value": value}
        for storage, bank, index, value in common
    ]


def condition_result_id(common):
    parts = ["cond"]
    for storage, bank, index, value in sorted(common, key=lambda t: (t[0], t[2])):
        parts.append("%s_%d_%d" % (storage, index, value))
    return "_".join(parts)


class ReproductionMismatch(Exception):
    pass


def _node_shell(group, dialogue_messages, event_played=True):
    """A result node for `group` with an explicit `dialogue_messages` slice,
    no reproduction check (used for a node that nests further - its own
    slice is a common prefix its children extend, not a full message list)."""
    return {
        "event_played": event_played,
        "dialogue_messages": dialogue_messages,
        "representative": group[0],
        "group": group,
        "choice": None,
        "results": None,
    }


def _leaf(group, consumed, event_played=True):
    """A result node for `group`, already known to be one signature: every
    candidate in it must share the exact same message list (the assertion
    that body/ancestor dialogue plus this leaf's own reproduces it)."""
    representative = group[0]
    rep_keys = [message_key(m) for m in representative["messages"]]
    for other in group:
        if [message_key(m) for m in other["messages"]] != rep_keys:
            raise ReproductionMismatch(
                "%s/%s and %s/%s share a signature but not their message list" % (
                    representative["route_id"], representative["variant_id"],
                    other["route_id"], other["variant_id"],
                )
            )
    return _node_shell(group, representative["messages"][consumed:], event_played)


def _others(all_candidates, group):
    """`all_candidates` minus `group`, by identity (candidate dicts are not
    hashable/comparable-by-value for this purpose)."""
    group_ids = {id(c) for c in group}
    return [c for c in all_candidates if id(c) not in group_ids]


def build_condition_node(group, consumed, unresolved):
    """A node for `group` split by exact outcome signature: a leaf when it
    is already one signature, else a `results`-only (no `choice`) split,
    each sub-result labelled by the writes that distinguish its variants
    from every other sub-group's (Rule A); an empty-conditions entry,
    flagged `unresolved`, when nothing distinguishes it."""
    sig_groups, sig_order = group_by_signature(group)
    if len(sig_order) == 1:
        return _leaf(group, consumed)
    common_prefix = longest_common_prefix([c["messages"][consumed:] for c in group])
    new_consumed = consumed + len(common_prefix)
    node = _node_shell(group, common_prefix)
    sub_results = {}
    unresolved_index = 0
    for sig in sig_order:
        subgroup = sig_groups[sig]
        distinguishing = distinguishing_writes(subgroup, _others(group, subgroup))
        sub_leaf = _leaf(subgroup, new_consumed)
        if distinguishing:
            sub_leaf["selected_by"] = {"kind": "condition", "conditions": condition_rows(distinguishing)}
            rid = condition_result_id(distinguishing)
        else:
            sub_leaf["selected_by"] = {"kind": "condition", "conditions": []}
            rid = "cond_unresolved_%d" % unresolved_index
            unresolved_index += 1
            unresolved.append(
                "variants %s of route(s) %s differ without a distinguishing write" % (
                    sorted({c["variant_id"] for c in subgroup}), sorted({c["route_id"] for c in subgroup}),
                )
            )
        sub_results[rid] = sub_leaf
    node["results"] = sub_results
    return node


def build_choice_node(group, second_contract, consumed, unresolved):
    """One node for a (possibly further-split) choice-value partition: a
    leaf when the group is already one signature, a nested `choice`+
    `results` when a second boundary differentiates any of it (residual
    variance inside one of its values still splits by condition, one level
    deeper), else a `results`-only (no `choice`) split by condition."""
    sig_groups, sig_order = group_by_signature(group)
    if len(sig_order) == 1:
        return _leaf(group, consumed)

    if second_contract is not None:
        boundary = int(second_contract["boundary_offset"])
        subgroups, suborder = partition_by_boundary(group, boundary)
        if len(suborder) > 1:
            common_prefix = longest_common_prefix([c["messages"][consumed:] for c in group])
            new_consumed = consumed + len(common_prefix)
            node = _node_shell(group, common_prefix)
            sub_results = {}
            for value in suborder:
                sub_node = build_condition_node(subgroups[value], new_consumed, unresolved)
                sub_node["selected_by"] = {"kind": "choice", "value": value}
                sub_results["answer%d" % value] = sub_node
            node["choice"] = {"contract": second_contract, "boundary": boundary, "order": suborder}
            node["results"] = sub_results
            return node

    return build_condition_node(group, consumed, unresolved)


def group_results(candidates, top_contract, second_contract, consumed=0):
    """Builds the document's `results` tree from `candidates` (from
    `build_candidate`). Returns `(results, choice_info_or_None, kind,
    unresolved_lines)`: `results` maps a result id to a node from `_leaf` /
    `build_choice_node`, each with `selected_by` filled in."""
    unresolved = []
    if top_contract is None:
        sig_groups, sig_order = group_by_signature(candidates)
        if len(sig_order) == 1:
            # The only group (trivially containing the baseline variant, or
            # the fewest-writes one on a route with no true baseline).
            node = _leaf(candidates, consumed)
            node["selected_by"] = {"kind": "default"}
            return {"result_default": node}, None, "event", unresolved
        results = {}
        unresolved_index = 0
        for sig in sig_order:
            group = sig_groups[sig]
            distinguishing = distinguishing_writes(group, _others(candidates, group))
            node = _leaf(group, consumed)
            if distinguishing:
                node["selected_by"] = {"kind": "condition", "conditions": condition_rows(distinguishing)}
                rid = condition_result_id(distinguishing)
            else:
                node["selected_by"] = {"kind": "condition", "conditions": []}
                rid = "result_unresolved_%d" % unresolved_index
                unresolved_index += 1
                unresolved.append(
                    "variants %s of route(s) %s differ without a distinguishing write" % (
                        sorted({c["variant_id"] for c in group}), sorted({c["route_id"] for c in group}),
                    )
                )
            results[rid] = node
        return results, None, "event", unresolved

    boundary = int(top_contract["boundary_offset"])
    groups, order = partition_by_boundary(candidates, boundary)
    results = {}
    for value in order:
        group = groups[value]
        skip_event = (
            all(int(c["variant"].get("message_count", 0)) == 0 for c in group)
            and all(not any(m["entry"] == c["route"]["callee"]["entry"] for m in c["messages"]) for c in group)
        )
        if skip_event:
            node = _leaf(group, consumed, event_played=False)
        else:
            node = build_choice_node(group, second_contract, consumed, unresolved)
        node["selected_by"] = {"kind": "choice", "value": value}
        results["answer%d" % value] = node
    choice_info = {"contract": top_contract, "boundary": boundary, "order": order}
    return results, choice_info, "choice_event", unresolved


TERMINAL_STATUS_MAP_SITE = {
    "script_handoff_boundary": "root_handoff",
    "script_return": "callee_return",
    "def_selection_boundary": "def_selection_boundary",
}


def terminal_from_route(route, caller_entry, callee_entry):
    """`{terminal_id: terminal_dict}` for one route: its own outcome, and
    (when the route declares one) its resume outcome. Ids are
    `<route_id>.outcome` / `<route_id>.resume`; dedupe with
    `dedupe_terminals`."""
    route_id = route["route_id"]
    out = {}
    outcome = route["outcome"]
    status = outcome.get("status")
    offset = int(outcome["offset"])
    end = int(outcome["end"])
    if status == "script_handoff_boundary":
        out[route_id + ".outcome"] = {
            "kind": "root_handoff", "owner_entry": callee_entry, "offset": offset, "end": end,
            "next_target": outcome.get("target", ""), "required_state": [],
        }
    elif status == "script_return":
        out[route_id + ".outcome"] = {
            "kind": "callee_return", "owner_entry": callee_entry, "offset": offset, "end": end,
            "required_state": [],
        }
    elif status == "def_selection_boundary":
        out[route_id + ".outcome"] = {
            "kind": "def_selection_boundary", "owner_entry": outcome.get("entry") or callee_entry,
            "offset": offset, "end": end, "required_state": [],
        }
    else:
        raise ValueError("unknown outcome status %r for route %s" % (status, route_id))

    resume = route.get("resume")
    if resume:
        policy = resume["boundary_policy"]
        r_outcome = resume["outcome"]
        r_offset = int(r_outcome["offset"])
        r_end = int(r_outcome["end"])
        if policy == "natural_handoff":
            out[route_id + ".resume"] = {
                "kind": "natural_handoff", "owner_entry": caller_entry, "offset": r_offset, "end": r_end,
                "next_target": r_outcome.get("target", ""), "required_state": [],
            }
        elif policy == "def_selection_boundary":
            out[route_id + ".resume"] = {
                "kind": "def_selection_boundary", "owner_entry": caller_entry, "offset": r_offset, "end": r_end,
                "required_state": [],
            }
        elif policy == "caller_menu_loop":
            loop = resume.get("loop") or {}
            out[route_id + ".resume"] = {
                "kind": "caller_menu_loop", "owner_entry": caller_entry, "offset": r_offset, "end": r_end,
                "required_state": [], "resume": {"period": loop.get("period"), "cycle": loop.get("cycle")},
            }
        elif policy == "stop_before_unprovided_dependency":
            out[route_id + ".resume"] = {
                "kind": "dependency_stop", "owner_entry": caller_entry, "offset": r_offset, "end": r_end,
                "required_state": [],
            }
        else:
            raise ValueError("unknown boundary_policy %r for route %s" % (policy, route_id))
    return out


def dedupe_terminals(terminals_by_id):
    """(deduped_terminals, id_remap): same (kind, owner_entry, offset, end)
    collapses to the first id seen, in `terminals_by_id`'s own order."""
    signature_to_id = {}
    id_remap = {}
    deduped = {}
    for tid, terminal in terminals_by_id.items():
        sig = (terminal["kind"], terminal["owner_entry"], terminal["offset"], terminal["end"])
        if sig in signature_to_id:
            id_remap[tid] = signature_to_id[sig]
        else:
            signature_to_id[sig] = tid
            id_remap[tid] = tid
            deduped[tid] = terminal
    return deduped, id_remap


SCENE_KIND_BY_MAP = {"TRAIN.MES": "train_ride", "GROUND.MES": "school_gate", "MACHI.MES": "town"}


def scene_kind_for_map(map_entry):
    if map_entry in SCENE_KIND_BY_MAP:
        return SCENE_KIND_BY_MAP[map_entry]
    stem = map_entry.split(".")[0].upper()
    if re.match(r"^FLOOR[1-5]$", stem):
        return "school_floor"
    return None


def scene_from_map_contract(contract):
    map_entry = contract["source_identity"]["entry"]
    kind = scene_kind_for_map(map_entry)
    if kind is None:
        raise ValueError("no scene kind for map %r" % map_entry)
    return {
        "kind": kind, "map": map_entry, "poll_offset": int(contract["poll_offset"]),
        "locations": [int(x) for x in contract.get("locations", [])],
        "spent_by": list(contract.get("spent_by", [])),
    }


def run_site(args):
    registry, names_fingerprint = load_registry(args.names)
    row = find_registry_row_by_id(registry, args.site)
    if row is None:
        print("REGISTRY ROW NOT FOUND for %s" % args.site)
        return 1
    if names_fingerprint == "unrecorded":
        print("names_fingerprint: unrecorded (registry at %s has no names_fingerprint file)" % args.names)
    else:
        print("names_fingerprint=%s" % names_fingerprint)

    profiles = load_profiles(args.profiles_dir)
    matches = resolve_site(row, profiles)
    if not matches:
        print("NO PROFILE MATCHES site %s (evidence=%s)" % (args.site, row["evidence"]))
        return 1
    preferred = choose_preferred(matches)
    routes = preferred["routes"]
    r1 = routes[0]
    profile_doc = preferred["doc"]
    stem = preferred["stem"]
    doc_id = row["id"]

    manifest = load_json(os.path.join(args.package, "manifest.json"))
    replay_doc = load_json(os.path.join(args.replays_dir, "%s.json" % stem))
    if replay_doc["archive_sha256"] != manifest["source"]["archive_sha256"]:
        print("ARCHIVE MISMATCH between replay and package manifest")
        return 1
    if replay_doc["archive_sha256"] != profile_doc["archive_sha256"]:
        print("ARCHIVE MISMATCH between replay and profile")
        return 1

    replay_route_by_id = {r["route_id"]: r for r in replay_doc["routes"]}
    for route in routes:
        if route["route_id"] not in replay_route_by_id:
            print("REPLAY MISSING route %s" % route["route_id"])
            return 1

    display = {
        "title_ko": row.get("title_ko", ""), "title_en": row.get("title_en", ""),
        "heroine": row.get("heroine", ""), "category": row.get("category", ""), "place": row.get("place", ""),
    }

    members = profile_doc.get("source_members", [])
    members_by_entry = {m["entry"]: m["entry_sha256"] for m in members}

    manifest_members = {e["entry"]: e["entry_sha256"] for e in manifest.get("entries", [])}
    for m in members:
        if m["entry"] in manifest_members and manifest_members[m["entry"]] != m["entry_sha256"]:
            print("PACKAGE MEMBER MISMATCH for %s" % m["entry"])
            return 1
    package_binding = {"schema": manifest["schema"], "package_sha256": manifest["package_sha256"]}

    groups_evidence = [
        {"group_id": m["group_id"], "profile_sha256": m["doc"]["payload_sha256"],
         "route_ids": [r["route_id"] for r in m["routes"]]}
        for m in matches
    ]
    groups_evidence.sort(key=lambda g: (g["group_id"], g["profile_sha256"]))

    evidence = {
        "kind": "analysis_group",
        "archive_sha256": profile_doc["archive_sha256"],
        "groups": groups_evidence,
        "members": [{"entry": m["entry"], "entry_sha256": m["entry_sha256"]} for m in members],
        "document_refs": [],
    }

    caller_entry = r1["caller"]["entry"]
    callee_entry = r1["callee"]["entry"]
    inference_unresolved = []

    caller_outcome_kind = (r1.get("caller_outcome") or {}).get("kind")
    caller_kind_map = {
        "dispatch": "nested_call", "root_handoff": "root_handoff",
        "nested_root_handoff": "nested_root_handoff", "blocked_definition": "nested_call",
    }
    trigger_caller_kind = caller_kind_map.get(caller_outcome_kind)
    if trigger_caller_kind is None:
        print("UNKNOWN caller_outcome.kind %r" % caller_outcome_kind)
        return 1
    if caller_outcome_kind == "blocked_definition":
        inference_unresolved.append("caller outcome blocked_definition")

    trigger = {
        "type": "caller_dispatch",
        "caller": {
            "entry": caller_entry, "entry_sha256": members_by_entry.get(caller_entry, ""),
            "offset": int(r1["caller"]["offset"]), "end": int(r1["caller"]["end"]),
            "command": int(r1["caller"]["command"]), "kind": trigger_caller_kind,
        },
        "callee": {
            "entry": callee_entry, "entry_sha256": members_by_entry.get(callee_entry, ""),
            "start_coordinate": int(r1["callee"]["offset"]),
        },
    }
    # The historical v1-v4 GROUND groups (schema v1..v3) never declared
    # origin_offset; docs/spec/data/event_definition_projection.md's "What
    # stays unresolved" names this gap explicitly. Fall back to the guard's
    # own offset (or the caller's dispatch offset, absent a guard) and record
    # the fallback in `unresolved` instead of refusing the site.
    if "origin_offset" in r1:
        origin_offset = int(r1["origin_offset"])
    elif r1.get("guard"):
        origin_offset = int(r1["guard"]["offset"])
        inference_unresolved.append(
            "origin not determined: historical v1-v4 GROUND group declares no origin_offset; "
            "the guard's own offset %d is used as a fallback origin (docs/spec/data/"
            "event_definition_projection.md, \"What stays unresolved\")" % origin_offset
        )
    else:
        origin_offset = int(r1["caller"]["offset"])
        inference_unresolved.append(
            "origin not determined: historical v1-v4 GROUND group declares no origin_offset and no "
            "guard; the caller's dispatch offset %d is used as a fallback origin (docs/spec/data/"
            "event_definition_projection.md, \"What stays unresolved\")" % origin_offset
        )
    map_contracts = r1.get("map_location_contracts") or []
    if map_contracts:
        trigger["origin"] = {
            "kind": "map_arrival", "offset": origin_offset,
            "contracts": [
                {"map": c["source_identity"]["entry"], "poll_offset": int(c["poll_offset"]),
                 "locations": [int(x) for x in c.get("locations", [])]}
                for c in map_contracts
            ],
        }
    elif r1.get("guard") and origin_offset == int(r1["guard"]["offset"]):
        trigger["origin"] = {"kind": "typed_guard", "offset": origin_offset}
    else:
        trigger["origin"] = {"kind": "caller_prefix", "offset": origin_offset}

    scenes = [scene_from_map_contract(c) for c in map_contracts]

    archive = Archive(args.arc)

    guard = None
    conditions = []
    conjunct_rows = []
    if r1.get("guard"):
        g = r1["guard"]
        parts = conjuncts(archive, caller_entry, int(g["offset"]))
        conjunct_rows = [map_conjunct(p, AFFECTION_HEROINE_LETTERS) for p in parts]
        witnesses = [
            {"case_id": case["case_id"], "writes": absolute_rows(case.get("writes", [])), "expected": int(case["expected"])}
            for case in r1.get("guard_cases", [])
        ]
        # The historical v1-v4 GROUND groups (schema v1..v4) name this hash
        # `prefix_sha256`, not `record_sha256`; same gap as origin_offset
        # above (docs/spec/data/event_definition_projection.md, "What stays
        # unresolved").
        record_sha256 = g.get("record_sha256")
        if record_sha256 is None:
            record_sha256 = g.get("prefix_sha256", "")
            inference_unresolved.append(
                "guard.record_sha256 not declared (historical v1-v4 GROUND group); "
                "guard.prefix_sha256 is used in its place"
            )
        guard = {
            "offset": int(g["offset"]), "end": int(g["end"]), "false_target": int(g["false_target"]),
            "record_sha256": record_sha256, "conjuncts": conjunct_rows, "witnesses": witnesses,
        }
        ast = guard_ast(archive, caller_entry, int(g["offset"]))
        conditions.append({
            "type": "mes_expression", "ast": ast, "source_offset": int(g["offset"]),
            "failure_reason": "guard_rejected",
        })

    reentry_r1 = r1.get("reentry")
    if reentry_r1 is not None:
        done_index = find_done_cell(conjunct_rows, r1)
        if done_index is not None:
            conditions.append({
                "type": "event_not_completed", "event_id": doc_id, "failure_reason": "already_completed",
                "done_cell": {"storage": "global_u8", "bank": 0, "index": done_index, "value": 1},
            })
            inference_unresolved.append("done_cell = the guard's cleared flag the event sets")
        else:
            inference_unresolved.append(
                "no done flag identified in the guard; the reentry is gated inside the callee "
                "(reentry emits %d messages)" % int(reentry_r1["message_count"])
            )

    presets = [{"preset_id": "baseline", "label": "baseline", "writes": absolute_rows(r1.get("baseline", []))}]
    seen_write_keys = set()
    for route in routes:
        for variant in route.get("variants", []):
            writes = variant.get("writes") or []
            if not writes:
                continue
            key = frozenset((w["storage"], int(w.get("bank", 0)), int(w["index"]), int(w["value"])) for w in writes)
            if key in seen_write_keys:
                continue
            seen_write_keys.add(key)
            presets.append({
                "preset_id": "%s/%s" % (route["route_id"], variant["variant_id"]),
                "label": variant["variant_id"], "writes": absolute_rows(writes),
            })

    top_contract, second_contract = choose_contracts(r1)

    candidates = []
    for route in routes:
        replay_route = replay_route_by_id[route["route_id"]]
        replay_variant_by_id = {v["variant_id"]: v for v in replay_route["variants"]}
        for variant in route.get("variants", []):
            vid = variant["variant_id"]
            if vid not in replay_variant_by_id:
                print("REPLAY MISSING variant %s/%s" % (route["route_id"], vid))
                return 1
            candidates.append(build_candidate(route, variant, replay_variant_by_id[vid]))

    body_messages = longest_common_prefix([c["messages"] for c in candidates])
    try:
        results_tree, choice_info, kind, group_unresolved = group_results(
            candidates, top_contract, second_contract, consumed=len(body_messages))
    except ReproductionMismatch as exc:
        print("REPRODUCTION MISMATCH: %s" % exc)
        return 1

    terminals_raw = {}
    for route in routes:
        terminals_raw.update(terminal_from_route(route, caller_entry, callee_entry))
    terminals, terminal_remap = dedupe_terminals(terminals_raw)

    body_after_keys = {
        (row["storage"], int(row.get("bank", 0)), int(row["index"])) for row in r1.get("expected_state", []) or []
    }
    body_after = effect_rows(r1.get("expected_state", []) or [])

    involved_entries = {callee_entry, caller_entry}
    for c in candidates:
        for m in c["messages"]:
            involved_entries.add(m["entry"])
    events_doc_by_entry = {entry: load_events_document(args.package, entry) for entry in involved_entries}

    report = {"missing_records": [], "missing_text_operand": []}
    body_dialogue = build_dialogue_list(body_messages, events_doc_by_entry, report)
    if body_dialogue is None:
        print("FATAL missing_text_operand in the body: %s" % report["missing_text_operand"])
        return 1

    after_unresolved = []

    def resolve_node(node):
        rep = node["representative"]
        dialogue = build_dialogue_list(node["dialogue_messages"], events_doc_by_entry, report)
        if dialogue is None:
            return None
        route = rep["route"]
        after_rows = group_after_effects(node["group"], body_after_keys, after_unresolved)
        terminal_key = route["route_id"] + (".resume" if route.get("resume") else ".outcome")
        result = {
            "selected_by": node["selected_by"],
            "event_played": node["event_played"],
            "dialogue": dialogue,
            "after": after_rows,
            "terminal": terminal_remap[terminal_key],
        }
        route_reentry = route.get("reentry")
        if route_reentry is not None:
            same = int(route_reentry["outcome"]["offset"]) == int(route["outcome"]["offset"])
            result["reentry"] = {
                "outcome": "same" if same else "other",
                "message_count": int(route_reentry["message_count"]),
                "after": effect_rows(route_reentry.get("expected_state", []) or []),
            }
        if node.get("results") is not None:
            sub_results = {}
            for rid, sub_node in node["results"].items():
                sub_result = resolve_node(sub_node)
                if sub_result is None:
                    return None
                sub_results[rid] = sub_result
            result["results"] = sub_results
        if node.get("choice") is not None:
            c = node["choice"]
            owner = contract_owner(c["contract"], rep["route"])
            result["choice"] = {
                "owner": owner, "boundary": c["boundary"],
                "position": "before_event" if owner == "caller" else "in_event",
                "options": [{"value": v, "result": "answer%d" % v} for v in c["order"]],
            }
        return result

    results = {}
    for rid, node in results_tree.items():
        resolved = resolve_node(node)
        if resolved is None:
            print("FATAL missing_text_operand in result %s: %s" % (rid, report["missing_text_operand"]))
            return 1
        results[rid] = resolved

    document_choice = None
    if choice_info is not None:
        owner = contract_owner(choice_info["contract"], r1)
        document_choice = {
            "owner": owner, "boundary": choice_info["boundary"],
            "position": "before_event" if owner == "caller" else "in_event",
            "options": [{"value": v, "result": "answer%d" % v} for v in choice_info["order"]],
        }

    exclude_entries = {caller_entry, callee_entry, "START.MES", "DEF_MAIN.MES", "LIBLARY.LIB"}
    dependencies = [
        {"entry": m["entry"], "entry_sha256": m["entry_sha256"], "role": "nested_presentation"}
        for m in members if m["entry"] not in exclude_entries
    ]

    final_unresolved = []
    for route in routes:
        final_unresolved.extend(route.get("unresolved", []) or [])
    for route in routes:
        if not route.get("resume"):
            continue
        replay_variant_by_id = {v["variant_id"]: v for v in replay_route_by_id[route["route_id"]]["variants"]}
        rv = replay_variant_by_id[route["variants"][0]["variant_id"]]
        n = len((rv.get("resume") or {}).get("messages", []) or [])
        final_unresolved.append(
            "resume emits %d caller messages after the event; not projected (v3 carries callee dialogue only)" % n
        )
    final_unresolved.extend(inference_unresolved)
    if len(matches) > 1:
        final_unresolved.append("site declared by %d profiles; trigger and results from %s" % (len(matches), stem))
    final_unresolved.extend(group_unresolved)
    final_unresolved.extend(after_unresolved)
    final_unresolved = list(dict.fromkeys(final_unresolved))  # dedupe, keep first-seen order

    document = {
        "schema_version": SCHEMA_VERSION,
        "contract_fingerprint": resolve_contract_fingerprint(args.contract_fingerprint),
        "names_fingerprint": names_fingerprint,
        "id": doc_id,
        "kind": kind,
        "display": display,
        "evidence": evidence,
        "package_binding": package_binding,
        "trigger": trigger,
        "scenes": scenes,
        "guard": guard,
        "conditions": conditions,
        "presets": presets,
        "dialogue": body_dialogue,
        "after": body_after,
        "results": results,
        "terminals": terminals,
        "dependencies": dependencies,
        "presentation": {"status": "deferred", "resources": []},
        "unresolved": final_unresolved,
    }
    if document_choice is not None:
        document["choice"] = document_choice

    os.makedirs(args.out, exist_ok=True)
    tracked_path = os.path.join(args.out, "%s.json" % doc_id)
    with open(tracked_path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(document, fh, indent=2, ensure_ascii=False, sort_keys=False)
        fh.write("\n")

    text_doc_by_entry = {entry: load_text_document(args.package, entry) for entry in involved_entries}

    def resolve_dialogue_entry(entry):
        resolved = json.loads(json.dumps(entry))
        if resolved.get("kind") == "text":
            text_ref = resolved["text_ref"]
            strings = text_doc_by_entry[text_ref["entry"]]["strings"]
            text_ref["text"] = strings[text_ref["s"]]
        return resolved

    def dialogue_script(dialogue_entries):
        lines = []
        for entry in dialogue_entries:
            if entry.get("kind") == "text":
                text_ref = entry["text_ref"]
                strings = text_doc_by_entry[text_ref["entry"]]["strings"]
                lines.append("-: %s" % strings[text_ref["s"]])
            elif entry.get("kind") == "name_insert":
                lines.append("-: {name}")
        return lines

    def resolve_result_tree(result):
        resolved = dict(result)
        resolved["dialogue"] = [resolve_dialogue_entry(e) for e in result["dialogue"]]
        script_lines = dialogue_script(result["dialogue"])
        script_lines.append("[terminal %s]" % result["terminal"])
        resolved["script"] = script_lines
        if result.get("results"):
            resolved["results"] = {rid: resolve_result_tree(sub) for rid, sub in result["results"].items()}
        return resolved

    resolved_document = json.loads(json.dumps(document))
    resolved_document["dialogue"] = [resolve_dialogue_entry(e) for e in body_dialogue]
    resolved_document["script"] = dialogue_script(body_dialogue)
    for result_id in results.keys():
        resolved_document["results"][result_id] = resolve_result_tree(results[result_id])

    resolved_dir = args.resolved_out or args.out
    os.makedirs(resolved_dir, exist_ok=True)
    resolved_path = os.path.join(resolved_dir, "%s.resolved.json" % doc_id)
    with open(resolved_path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(resolved_document, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    def count_messages(result):
        total = len(result["dialogue"])
        for sub in (result.get("results") or {}).values():
            total += count_messages(sub)
        return total

    print("PROJECTED %s" % doc_id)
    print("body_messages=%d" % len(body_dialogue))
    for result_id, result in results.items():
        print("result %s messages=%d terminal=%s" % (result_id, count_messages(result), result["terminal"]))
    print("results=%d terminals=%d" % (len(results), len(terminals)))
    if report["missing_records"]:
        print("UNRESOLVED missing_records=%s" % [
            "%s@%d" % (r["entry"], r["at"]) for r in report["missing_records"]
        ])
    print("WROTE %s" % tracked_path)
    print("WROTE %s" % resolved_path)
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog")
    parser.add_argument("--event")
    parser.add_argument("--site")
    parser.add_argument("--profiles-dir", default=os.path.join("config", "event_catalog", "analysis_groups"))
    parser.add_argument("--replays-dir", default=os.path.join("analysis", "replays"))
    parser.add_argument("--names", required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--replay")
    parser.add_argument("--arc", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--resolved-out", default=None,
                        help="directory for the local .resolved.json (dialogue text); defaults to --out")
    parser.add_argument("--allow-unrecorded", action="store_true")
    parser.add_argument("--contract-fingerprint", default=DEFAULT_CONTRACT_FINGERPRINT_PATH)
    args = parser.parse_args()

    if bool(args.event) == bool(args.site):
        print("exactly one of --event or --site is required")
        return 1

    if args.event:
        if not args.catalog or not args.replay:
            print("--event requires --catalog and --replay")
            return 1
        return run_catalog(args)
    return run_site(args)


if __name__ == "__main__":
    sys.exit(main())
