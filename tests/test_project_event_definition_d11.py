"""TD-56 D11 (owner ruling 2026-10-11): call-argument storage is not an event effect.

Synthetic inputs only: no archive, no package on disk. A `global_i32` net change of a run
is argument storage when the run executed a command-`0x09` record whose write range covers
the index and whose literal equals the change's `after` (in a flow variant a covering
record of an earlier hop counts too). It leaves the effect derivation (no `after` row, no
witness row) and is recorded once per `(index, value)` in `unresolved`; a `global_i32`
change with no such record keeps the ordinary path.

The invented world:

- `A.MES` has a command-`0x09` record at 10 (`global_i32[1] = 67616`), at 20 (slots 1 and 2
  = 3 and 4), at 30 (slot 1 = an expression) and an unrelated record at 40.
- `LIB.LIB` (a library: records inside routines) has a command-`0x09` record at 100
  (`global_i32[2] = 9`).
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import project_event_definition as ped  # noqa: E402
import project_event_definition_v4 as p4  # noqa: E402
import project_event_definition_v5 as p5  # noqa: E402
import project_event_definition_v6 as p6  # noqa: E402
import state_cells  # noqa: E402


def literal(value):
    return {"ast": {"type": "literal", "value": value, "width": 8}, "continuation": 0}


def write09(at, start, pairs):
    return {"op": "argument_slot_write_run", "id": 9, "at": at, "end": at + 6,
            "operands": [{"t": "u16_index", "v": start}, {"t": "expression_byte_pairs", "pairs": pairs}]}


DOCUMENTS = {
    "A.MES": {"kind": "event", "records": [
        write09(10, 1, [literal(67616)]),
        write09(20, 1, [literal(3), literal(4)]),
        write09(30, 1, [{"ast": {"type": "state_ref", "storage": "global_u8", "index": {"type": "literal", "value": 5}}, "continuation": 0}]),
        {"op": "text_run", "id": 1, "at": 40, "end": 44, "operands": []},
    ]},
    "LIB.LIB": {"kind": "library", "routines": [{"records": [write09(100, 2, [literal(9)])]}]},
}


def load_document(entry):
    return DOCUMENTS[entry]


def change(storage, index, before, after, bank=0):
    return {"storage": storage, "bank": bank, "index": index, "before": before, "after": after}


def net(*changes):
    return {(c["storage"], c["bank"], c["index"]): c for c in changes}


class ParseTests(unittest.TestCase):
    def test_a_plain_member_and_a_library_are_both_read(self) -> None:
        self.assertEqual(ped.command_09_writes(DOCUMENTS["A.MES"]),
                         {10: (1, [67616]), 20: (1, [3, 4]), 30: (1, [None])})
        self.assertEqual(ped.command_09_writes(DOCUMENTS["LIB.LIB"]), {100: (2, [9])})

    def test_other_records_and_other_commands_are_not_command_09(self) -> None:
        other = {"kind": "event", "records": [dict(write09(10, 1, [literal(1)]), id=22), {"op": "text_run", "id": 9, "at": 12, "operands": []}]}
        self.assertEqual(ped.command_09_writes(other), {})


class SplitTests(unittest.TestCase):
    def storage(self):
        return ped.ArgumentStorage(load_document)

    def test_a_covering_literal_leaves_the_change_out_and_is_recorded(self) -> None:
        storage = self.storage()
        changes = net(change("global_i32", 1, 0, 67616), change("global_u8", 4000, 0, 1))
        kept = storage.split(changes, [{"A.MES": [10, 40]}])
        self.assertEqual(sorted(kept), [("global_u8", 0, 4000)])
        self.assertEqual(storage.lines(), [
            "argument storage: global_i32[1] = 67616 written by command 0x09 at A.MES:10; not an event effect (TD-56 D11)"])

    def test_a_second_slot_of_the_same_record_is_covered(self) -> None:
        storage = self.storage()
        kept = storage.split(net(change("global_i32", 2, 0, 4)), [{"A.MES": [20]}])
        self.assertEqual(kept, {})
        self.assertEqual(storage.writers, {(2, 4): ("A.MES", 20)})

    def test_a_library_record_covers_too(self) -> None:
        storage = self.storage()
        kept = storage.split(net(change("global_i32", 2, 0, 9)), [{"A.MES": [40], "LIB.LIB": [100]}])
        self.assertEqual(kept, {})
        self.assertEqual(storage.lines(), [
            "argument storage: global_i32[2] = 9 written by command 0x09 at LIB.LIB:100; not an event effect (TD-56 D11)"])

    def test_a_literal_that_is_not_the_after_value_keeps_the_ordinary_path(self) -> None:
        storage = self.storage()
        changes = net(change("global_i32", 1, 0, 5))
        self.assertEqual(storage.split(changes, [{"A.MES": [10, 20]}]), changes)
        self.assertEqual(storage.lines(), [])

    def test_an_expression_valued_write_does_not_cover(self) -> None:
        storage = self.storage()
        changes = net(change("global_i32", 1, 0, 7))
        self.assertEqual(storage.split(changes, [{"A.MES": [30]}]), changes)

    def test_a_record_that_the_run_did_not_execute_does_not_cover(self) -> None:
        storage = self.storage()
        changes = net(change("global_i32", 1, 0, 67616))
        self.assertEqual(storage.split(changes, [{"A.MES": [20, 40]}]), changes)
        self.assertEqual(storage.split(changes, [{}, None]), changes)
        self.assertEqual(storage.split(changes, []), changes)

    def test_an_index_outside_the_write_range_does_not_cover(self) -> None:
        storage = self.storage()
        changes = net(change("global_i32", 3, 0, 4))
        self.assertEqual(storage.split(changes, [{"A.MES": [20]}]), changes)

    def test_only_global_i32_is_ever_argument_storage(self) -> None:
        storage = self.storage()
        changes = net(change("global_u8", 1, 0, 67616), change("banked_u16", 1, 0, 67616))
        self.assertEqual(storage.split(changes, [{"A.MES": [10]}]), changes)

    def test_nothing_is_loaded_without_a_global_i32_change(self) -> None:
        loaded = []
        storage = ped.ArgumentStorage(lambda entry: loaded.append(entry) or DOCUMENTS[entry])
        storage.split(net(change("global_u8", 4000, 0, 1)), [{"A.MES": [10]}])
        self.assertEqual(loaded, [])

    def test_the_smallest_covering_record_is_named_and_a_cell_is_listed_once(self) -> None:
        storage = self.storage()
        storage.split(net(change("global_i32", 1, 0, 3)), [{"A.MES": [20]}])
        storage.split(net(change("global_i32", 1, 0, 3)), [{"A.MES": [20]}])
        self.assertEqual(len(storage.lines()), 1)
        extra = {"kind": "event", "records": [write09(5, 1, [literal(3)])]}
        documents = dict(DOCUMENTS, **{"A.MES": {"kind": "event", "records": DOCUMENTS["A.MES"]["records"] + extra["records"]}})
        storage = ped.ArgumentStorage(documents.__getitem__)
        storage.split(net(change("global_i32", 1, 0, 3)), [{"A.MES": [20, 5]}])
        self.assertEqual(storage.writers, {(1, 3): ("A.MES", 5)})

    def test_two_values_of_one_cell_are_two_lines(self) -> None:
        storage = self.storage()
        storage.split(net(change("global_i32", 1, 0, 3)), [{"A.MES": [20]}])
        storage.split(net(change("global_i32", 1, 0, 67616)), [{"A.MES": [10]}])
        self.assertEqual([line.split(" written")[0] for line in storage.lines()],
                         ["argument storage: global_i32[1] = 3", "argument storage: global_i32[1] = 67616"])


class MergeTests(unittest.TestCase):
    LINE = ped.ARGUMENT_STORAGE_LINE

    def test_ordinary_lines_are_deduplicated_in_first_seen_order(self) -> None:
        self.assertEqual(ped.merge_unresolved(["b", "a", "b", "c", "a"]), ["b", "a", "c"])

    def test_the_lines_of_one_cell_collapse_to_the_smallest_writer_at_the_first_position(self) -> None:
        merged = ped.merge_unresolved([
            "x", self.LINE % (1, 3, "B.MES", 7), "y", self.LINE % (1, 3, "A.MES", 90), self.LINE % (2, 3, "B.MES", 7)])
        self.assertEqual(merged, ["x", self.LINE % (1, 3, "A.MES", 90), "y", self.LINE % (2, 3, "B.MES", 7)])


def replay_variant(**fields):
    base = {"state_changes": {}, "prefix_executed": {}, "executed": {}, "resume": None, "messages": [], "terminal": {}}
    base.update(fields)
    return base


class CandidateTests(unittest.TestCase):
    ROUTE = {"route_id": "r0"}
    VARIANT = {"variant_id": "v0", "writes": [], "expected_state": []}

    def candidate(self, rv, storage):
        return p4.build_candidate_v4(self.ROUTE, self.VARIANT, rv, None, None, "CALLER.MES", "CALLEE.MES", argument_storage=storage)

    def test_the_prefix_callee_and_resume_runs_all_count(self) -> None:
        for field in ("prefix", "callee", "resume"):
            executed = {"A.MES": [10]}
            rv = replay_variant(state_changes={field: [change("global_i32", 1, 0, 67616), change("global_u8", 4000, 0, 1)]})
            if field == "prefix":
                rv["prefix_executed"] = executed
            elif field == "callee":
                rv["executed"] = executed
            else:
                rv["resume"] = {"messages": [], "terminal": {"entry": "C", "status": "s", "offset": 1, "target": ""}, "executed": executed}
            storage = ped.ArgumentStorage(load_document)
            self.assertEqual(sorted(self.candidate(rv, storage)["net_changes"]), [("global_u8", 0, 4000)], field)
            self.assertEqual(len(storage.lines()), 1, field)

    def test_without_the_storage_or_without_executed_nothing_changes(self) -> None:
        rv = replay_variant(state_changes={"callee": [change("global_i32", 1, 0, 67616)]}, executed={"A.MES": [10]})
        self.assertEqual(sorted(self.candidate(rv, None)["net_changes"]), [("global_i32", 0, 1)])
        v2 = replay_variant(state_changes={"callee": [change("global_i32", 1, 0, 67616)]})
        del v2["executed"], v2["prefix_executed"]
        self.assertEqual(sorted(self.candidate(v2, ped.ArgumentStorage(load_document))["net_changes"]), [("global_i32", 0, 1)])

    def test_an_uncovered_global_i32_change_still_reaches_the_effect_derivation(self) -> None:
        rv = replay_variant(state_changes={"callee": [change("global_i32", 1, 0, 5)]}, executed={"A.MES": [10]})
        candidate = self.candidate(rv, ped.ArgumentStorage(load_document))
        unresolved = []
        rows, _evidence = p4.decide_effects_for_group([candidate], "result_default", state_cells.load(), {}, unresolved)
        self.assertEqual(rows, [])
        self.assertEqual(len(unresolved), 1)
        self.assertIn("effect on global_i32[1] for result result_default: no matching shift witness", unresolved[0])

    def test_a_covered_change_yields_no_row_no_evidence_and_no_unresolved_effect_line(self) -> None:
        rv = replay_variant(state_changes={"callee": [change("global_i32", 1, 0, 67616)]}, executed={"A.MES": [10]})
        candidate = self.candidate(rv, ped.ArgumentStorage(load_document))
        unresolved = []
        rows, evidence = p4.decide_effects_for_group([candidate], "result_default", state_cells.load(), {}, unresolved)
        self.assertEqual((rows, evidence, unresolved), ([], [], []))


class VisitTests(unittest.TestCase):
    def test_a_visit_uses_its_own_run(self) -> None:
        visits = [{"visit_id": "a", "_route_id": "r"}, {"visit_id": "b", "_route_id": "r"}]
        replay = {
            "a": {"state_diff": [change("global_i32", 1, 0, 67616)], "executed": {"A.MES": [10]}},
            "b": {"state_diff": [change("global_i32", 1, 0, 67616)], "executed": {"A.MES": [40]}},
        }
        storage = ped.ArgumentStorage(load_document)
        unresolved = []
        rows = p5.build_visit_effects(visits, replay, state_cells.load(), unresolved, argument_storage=storage)
        self.assertEqual(rows, {"a": [], "b": []})
        # `a` is argument storage; `b` ran no covering record, so its change takes the ordinary path
        # (and, alone in its entry state with no witness, is an unresolved effect line).
        self.assertEqual(len(storage.lines()), 1)
        self.assertEqual(len(unresolved), 1)
        self.assertIn("global_i32[1]", unresolved[0])


class FlowTests(unittest.TestCase):
    def variant(self, hop0_executed, hop1_executed):
        return {"hops": [
            {"hop_id": "h0", "executed": hop0_executed, "state_changes": [change("global_i32", 1, 0, 67616)]},
            {"hop_id": "h1", "executed": hop1_executed, "state_changes": [change("global_i32", 1, 0, 67616), change("global_u8", 4090, 0, 1)]},
        ], "state_changes": [change("global_i32", 1, 0, 67616), change("global_u8", 4090, 0, 1)]}

    def test_a_hop_counts_its_own_run(self) -> None:
        variant = self.variant({"A.MES": [10]}, {"A.MES": [40]})
        storage = ped.ArgumentStorage(load_document)
        self.assertEqual(p6.flow_hop_net_changes(storage, variant, 0), {})

    def test_a_covering_record_of_an_earlier_hop_counts(self) -> None:
        variant = self.variant({"A.MES": [10]}, {"A.MES": [40]})
        storage = ped.ArgumentStorage(load_document)
        self.assertEqual(sorted(p6.flow_hop_net_changes(storage, variant, 1)), [("global_u8", 0, 4090)])
        self.assertEqual(len(storage.lines()), 1)

    def test_a_later_hop_does_not_cover_an_earlier_one(self) -> None:
        variant = self.variant({"A.MES": [40]}, {"A.MES": [10]})
        storage = ped.ArgumentStorage(load_document)
        self.assertEqual(sorted(p6.flow_hop_net_changes(storage, variant, 0)), [("global_i32", 0, 1)])
        self.assertEqual(sorted(p6.flow_hop_net_changes(storage, variant, 1)), [("global_u8", 0, 4090)])

    def test_the_body_may_be_covered_by_any_hop(self) -> None:
        variant = self.variant({"A.MES": [40]}, {"A.MES": [10]})
        storage = ped.ArgumentStorage(load_document)
        self.assertEqual(sorted(p6.flow_body_net_changes(storage, variant)), [("global_u8", 0, 4090)])

    def test_no_covering_record_in_any_hop_keeps_the_change(self) -> None:
        variant = self.variant({"A.MES": [40]}, {"A.MES": [30]})
        storage = ped.ArgumentStorage(load_document)
        self.assertEqual(sorted(p6.flow_body_net_changes(storage, variant)), [("global_i32", 0, 1), ("global_u8", 0, 4090)])
        self.assertEqual(storage.lines(), [])


if __name__ == "__main__":
    unittest.main()
