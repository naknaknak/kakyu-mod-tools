from copy import deepcopy
import contextlib
import hashlib
import io
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from audit_event_analysis_group import (audit, main, SCHEMA, V2_SCHEMA, V3_SCHEMA, V4_SCHEMA, V5_SCHEMA,
                                        V6_SCHEMA, V7_SCHEMA, V8_SCHEMA, V9_SCHEMA, V10_SCHEMA,
                                        V11_SCHEMA, V12_SCHEMA, V13_SCHEMA, V14_SCHEMA)
from build_event_flow_profile import build_flow_profile
from build_event_analysis_inventory import fingerprint
from mes_analyzer_handoff import build_handoff
from payload_values import map_location_poll


class EventAnalysisGroupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.arc = Path(self.temp.name) / "mes.arc"
        condition = bytes([0xF3,1,0,0,0xEF,0xFF])  # global_u8[1] == 0
        start = 1 + len(condition) + 4
        dispatch = b"\x0f\x01QA.MES\0\0"
        end = start + len(dispatch)
        code = b"\x0b" + condition + struct.pack("<I", end) + dispatch + b"\0"
        caller, callee = b"\0" * 4 + code, b"\0" * 5
        self.arc.write_bytes(caller + callee)
        self.entries = [("CALLER.MES",0,len(caller)),("QA.MES",len(caller),len(callee))]
        self.profile = {"schema":SCHEMA,"group_id":"synthetic","archive_sha256":hashlib.sha256(caller+callee).hexdigest(),
            "source_members":[{"entry":name,"entry_sha256":hashlib.sha256(payload).hexdigest()} for name,payload in [("CALLER.MES",caller),("QA.MES",callee)]],
            "routes":[{"route_id":"qa","caller":{"entry":"CALLER.MES","offset":start,"end":end,"command":15},
                "callee":{"entry":"QA.MES","offset":0},
                "guard":{"offset":0,"end":start,"false_target":end,"prefix_sha256":hashlib.sha256(code[:end]).hexdigest()},
                "caller_outcome":{"kind":"dispatch"},
                "outcome":{"offset":0,"end":1,"op":"command_00","status":"script_return"},
                "baseline":[],"expected_state":[],"variants":[{"variant_id":"default","writes":[]}],
                "guard_cases":[{"case_id":"yes","writes":[],"expected":1},
                    {"case_id":"no","writes":[{"storage":"global_u8","bank":0,"index":1,"value":1}],"expected":0}]}]}
        self.sign()

    def sign(self):
        self.profile["payload_sha256"] = fingerprint(self.profile)

    def run_audit(self):
        with patch("audit_event_analysis_group.read_entries", return_value=self.entries):
            return audit(self.arc, self.profile)

    def root_replacement_profile(self, *, opaque=False, choices=False, terminal="handoff", bypass=False, nested=False):
        self.observed_guard_profile(opaque=opaque, choices=choices)
        route = self.profile["routes"][0]
        if bypass:
            self.add_bypass()
        archive = self.arc.read_bytes()
        caller_size = self.entries[0][2]
        caller = bytearray(archive[:caller_size])
        # A nested root handoff keeps the command-0F call the fixture already
        # carries; the callee's own handoff is what replaces the root.
        caller[4 + route["caller"]["offset"]] = 15 if nested else 14
        callee_code = archive[caller_size + 4:route["outcome"]["offset"] + caller_size + 4]
        # Keep offset zero typed even when the observed terminal is opaque.
        if not callee_code:
            callee_code = b"\x1f\0\0\0\0"
        if opaque:
            callee_code += b"\x08\xff"
        terminal_bytes, op, status = {
            "handoff": (b"\x0e\x01MACHI.MES\0\0", "script_handoff_marker", "script_handoff_boundary"),
            "return": (b"\0", "command_00", "script_return"),
            "selection": (b"\x1d\x02\x28\xff\0", "script_transfer", "def_selection_boundary"),
        }[terminal]
        out = {"offset":len(callee_code), "end":len(callee_code) + len(terminal_bytes), "op":op, "status":status}
        if terminal == "handoff":
            out["target"] = "MACHI.MES"
        callee = b"\0" * 4 + callee_code + terminal_bytes
        payloads = {"CALLER.MES":bytes(caller), "QA.MES":callee}
        archive = bytes(caller) + callee
        self.arc.write_bytes(archive)
        self.entries = [("CALLER.MES", 0, len(caller)), ("QA.MES", len(caller), len(callee))]
        self.profile["schema"] = V6_SCHEMA
        self.profile["archive_sha256"] = hashlib.sha256(archive).hexdigest()
        self.profile["source_members"] = [{"entry":name, "entry_sha256":hashlib.sha256(data).hexdigest()}
            for name, data in payloads.items()]
        route["caller"]["command"] = 15 if nested else 14
        route["caller_outcome"] = {"kind":"nested_root_handoff" if nested else "root_handoff"}
        route.update(qualification="root_replacement_observation", post_guard_expected=0, outcome=out)
        route["guard"]["prefix_sha256"] = hashlib.sha256(caller[4:4 + route["caller"]["end"]]).hexdigest()
        del route["resume"]
        del route["variants"][0]["expected_resume_state"]
        def bind(entry, observation):
            payload = payloads[entry]
            doc = build_handoff(payload)
            tail = next((tail for tail in doc["typed_ir"]["opaque_boundaries"]
                if tail["source_offset"] <= observation["offset"] < observation["end"] <= tail["end_offset"]), None)
            observation["source_binding"] = ({"kind":"runtime_observation_in_opaque_tail",
                "offset":tail["source_offset"], "end":tail["end_offset"], "sha256":tail["raw_sha256"]}
                if tail else {"kind":"typed_record"})
            observation["record_sha256"] = hashlib.sha256(payload[4 + observation["offset"]:4 + observation["end"]]).hexdigest()
        bind("CALLER.MES", route["caller"])
        bind("CALLER.MES", route["guard"])
        bind("QA.MES", out)
        route["reentry"]["outcome"] = deepcopy(out)
        for item in route.get("bypass_variants", []):
            bind("CALLER.MES", item["outcome"])
        for contract in route["choice_contracts"]:
            code = payloads[contract["source_identity"]["entry"]][4:]
            contract.update(bytecode_sha256=hashlib.sha256(code).hexdigest(), code_size=len(code))
        self.sign()

    def unconditional_profile(self, *, escaping=False, terminal="handoff"):
        """A v7 caller whose dispatch no edge in the declared window can skip."""
        self.root_replacement_profile(terminal=terminal)
        route = self.profile["routes"][0]
        archive = self.arc.read_bytes()
        callee = archive[self.entries[0][2]:]
        condition = bytes([0xF3, 1, 0, 0, 0xEF, 0xFF])  # global_u8[1] == 0
        head = bytes([0x0B]) + condition
        dispatch = bytes([0x0E, 0x01]) + b"QA.MES" + bytes([0, 0])
        branch_size = len(head) + 4
        target = branch_size + len(dispatch) if escaping else branch_size
        code = head + struct.pack("<I", target) + dispatch + bytes([0])
        caller = bytes(4) + code
        archive = caller + callee
        self.arc.write_bytes(archive)
        self.entries = [("CALLER.MES", 0, len(caller)), ("QA.MES", len(caller), len(callee))]
        self.profile["schema"] = V7_SCHEMA
        self.profile["archive_sha256"] = hashlib.sha256(archive).hexdigest()
        self.profile["source_members"] = [
            {"entry": "CALLER.MES", "entry_sha256": hashlib.sha256(caller).hexdigest()},
            {"entry": "QA.MES", "entry_sha256": hashlib.sha256(callee).hexdigest()}]
        route["caller"].update(offset=branch_size, end=branch_size + len(dispatch), command=14,
            source_binding={"kind": "typed_record"},
            record_sha256=hashlib.sha256(dispatch).hexdigest())
        route["qualification"] = "unconditional_root_replacement_observation"
        route["unconditional_dispatch"] = {"record_count": 1, "edge_count": 1,
            "return_candidate_offsets": [],
            "prefix_sha256": hashlib.sha256(code[:branch_size + len(dispatch)]).hexdigest()}
        route["origin_offset"] = 0
        route["selection_cases"] = [{"case_id": case["case_id"], "writes": case["writes"],
                                     "caller_message_count": 0} for case in route.pop("guard_cases")]
        del route["guard"]
        del route["post_guard_expected"]
        self.sign()

    def test_v7_unconditional_dispatch_is_bound_to_the_original_window(self):
        self.unconditional_profile()
        report = self.run_audit()
        self.assertEqual(report, self.run_audit())
        self.assertEqual(report["schema"], "kakyu_event_analysis_group_source_audit/v7")
        self.assertIn("no_completion_claim", report["qualification"])
        window = report["unconditional_dispatch_windows"][report["profile"]["routes"][0]["route_id"]]
        self.assertEqual(window["escaping_edges"], [])
        self.assertEqual(window["interior_dispatch_offsets"], [])
        self.assertEqual(window["opaque_overlaps"], [])
        self.assertEqual(window["record_count"], 1)

    def test_v7_rejects_a_window_whose_edge_skips_the_dispatch(self):
        self.unconditional_profile(escaping=True)
        with self.assertRaises(ValueError):
            self.run_audit()

    def test_v7_unguarded_declarations_fail_closed(self):
        self.unconditional_profile()
        original = deepcopy(self.profile)
        mutations = {
            "record_count": lambda r: r["unconditional_dispatch"].update(record_count=2),
            "record_count_zero": lambda r: r["unconditional_dispatch"].update(record_count=0),
            "record_count_bool": lambda r: r["unconditional_dispatch"].update(record_count=True),
            "edge_count": lambda r: r["unconditional_dispatch"].update(edge_count=0),
            "edge_count_negative": lambda r: r["unconditional_dispatch"].update(edge_count=-1),
            "returns": lambda r: r["unconditional_dispatch"].update(return_candidate_offsets=[0]),
            "prefix": lambda r: r["unconditional_dispatch"].update(prefix_sha256="0" * 64),
            "guard_present": lambda r: r.update(guard={"offset": 0, "end": 11, "false_target": 11}),
            "post_guard": lambda r: r.update(post_guard_expected=0),
            "variant_post_guard": lambda r: r["variants"][0].update(post_guard_expected=0),
            "guard_truth": lambda r: r["selection_cases"][0].update(expected=1),
            "guarded_qualification": lambda r: r.update(qualification="root_replacement_observation"),
            "origin_inside_a_record": lambda r: r.update(origin_offset=1),
            "origin_past_dispatch": lambda r: r.update(origin_offset=r["caller"]["offset"] + 1),
            "no_selection_cases": lambda r: r.update(selection_cases=[]),
            "duplicate_selection_case": lambda r: r["selection_cases"].append(deepcopy(r["selection_cases"][0])),
        }
        for name, mutate in mutations.items():
            self.profile = deepcopy(original)
            mutate(self.profile["routes"][0])
            self.sign()
            with self.subTest(mutation=name), self.assertRaises((ValueError, KeyError)):
                self.run_audit()

    def test_v6_root_replacements_bind_all_terminal_types_and_preserve_opaque_classification(self):
        for opaque in (False, True):
            for terminal in ("return", "selection", "handoff"):
                with self.subTest(opaque=opaque, terminal=terminal):
                    self.root_replacement_profile(opaque=opaque, choices=True, terminal=terminal, bypass=True)
                    report = self.run_audit()
                    self.assertEqual(report, self.run_audit())
                    self.assertEqual(report["schema"], "kakyu_event_analysis_group_source_audit/v6")
                    self.assertIn("no_completion_claim", report["qualification"])
                    route = report["profile"]["routes"][0]
                    self.assertNotIn("resume", route)
                    self.assertEqual(route["outcome"]["source_binding"]["kind"],
                        "runtime_observation_in_opaque_tail" if opaque else "typed_record")
                    self.assertTrue(all(row["producer"] == "python_phase1_4" for row in report["handoffs"].values()))

    def test_v6_nested_root_handoff_binds_a_command_0f_caller_whose_callee_replaces_the_root(self):
        """A nested call whose callee hands the root on is a root replacement too."""
        for terminal in ("return", "selection", "handoff"):
            with self.subTest(terminal=terminal):
                self.root_replacement_profile(choices=True, terminal=terminal, nested=True)
                report = self.run_audit()
                self.assertEqual(report, self.run_audit())
                route = report["profile"]["routes"][0]
                self.assertEqual(route["caller"]["command"], 15)
                self.assertEqual(route["caller_outcome"], {"kind": "nested_root_handoff"})
                self.assertNotIn("resume", route)

    def test_v6_nested_root_handoff_fails_closed_on_the_other_caller_command(self):
        """The two outcome kinds each bind exactly one caller command."""
        self.root_replacement_profile(nested=True)
        original = deepcopy(self.profile)
        mutations = {
            "declares_0e_for_a_0f_record": lambda r: r["caller"].update(command=14),
            "names_the_plain_handoff_kind": lambda r: r.update(caller_outcome={"kind": "root_handoff"}),
            "names_a_dispatch": lambda r: r.update(caller_outcome={"kind": "dispatch"}),
            "claims_a_resume": lambda r: r.update(resume={}),
        }
        for name, mutate in mutations.items():
            self.profile = deepcopy(original)
            mutate(self.profile["routes"][0])
            self.sign()
            with self.subTest(mutation=name), self.assertRaises((ValueError, KeyError)):
                self.run_audit()
        self.root_replacement_profile()
        self.profile["routes"][0]["caller_outcome"] = {"kind": "nested_root_handoff"}
        self.sign()
        with self.assertRaises(ValueError):
            self.run_audit()

    def test_v6_root_replacement_rejects_resume_and_forged_root_semantics(self):
        self.root_replacement_profile()
        original = deepcopy(self.profile)
        mutations = {
            "command": lambda r: r["caller"].update(command=15),
            "dispatch": lambda r: r.update(caller_outcome={"kind":"dispatch"}),
            "extra_caller_claim": lambda r: r["caller_outcome"].update(resume=0),
            "qualification": lambda r: r.update(qualification="caller_continuation_observation"),
            "callee_start": lambda r: r["callee"].update(offset=5),
            "callee_bool": lambda r: r["callee"].update(offset=False),
            "resume": lambda r: r.update(resume={}),
            "route_resume_state": lambda r: r.update(expected_resume_state=[]),
            "variant_resume": lambda r: r["variants"][0].update(resume={}),
            "variant_resume_state": lambda r: r["variants"][0].update(expected_resume_state=[]),
            "post_guard_missing": lambda r: r.pop("post_guard_expected"),
        }
        for name, mutate in mutations.items():
            self.profile = deepcopy(original)
            mutate(self.profile["routes"][0])
            self.sign()
            with self.subTest(mutation=name), self.assertRaises((ValueError, KeyError)):
                self.run_audit()
        for owner in ("route", "variant"):
            for value in (True, False, -1, 2, 0.0, "0", None):
                self.profile = deepcopy(original)
                route = self.profile["routes"][0]
                (route if owner == "route" else route["variants"][0])["post_guard_expected"] = value
                self.sign()
                with self.subTest(owner=owner, value=value), self.assertRaises(ValueError):
                    self.run_audit()

    def test_v6_terminal_and_reentry_override_bindings_fail_closed(self):
        self.root_replacement_profile(opaque=True, choices=True)
        route = self.profile["routes"][0]
        route["variants"][0].update(post_guard_expected=1, reentry=deepcopy(route["reentry"]))
        self.sign()
        self.assertTrue(self.run_audit()["ok"])
        original = deepcopy(self.profile)
        for owner in ("outcome", "reentry", "override"):
            for mutation in ("offset", "fraction", "end", "op", "status", "target", "missing_hash", "hash",
                             "missing_binding", "typed_opaque", "tail_hash", "tail_bounds"):
                self.profile = deepcopy(original)
                route = self.profile["routes"][0]
                out = (route["outcome"] if owner == "outcome" else route["reentry"]["outcome"] if owner == "reentry"
                       else route["variants"][0]["reentry"]["outcome"])
                if mutation == "offset": out["offset"] += 1
                elif mutation == "fraction": out["offset"] += 0.5
                elif mutation == "end": out["end"] -= 1
                elif mutation == "op": out["op"] = "command_00"
                elif mutation == "status": out["status"] = "script_return"
                elif mutation == "target": out["target"] = "CHANGED.MES"
                elif mutation == "missing_hash": del out["record_sha256"]
                elif mutation == "hash": out["record_sha256"] = "0" * 64
                elif mutation == "missing_binding": del out["source_binding"]
                elif mutation == "typed_opaque": out["source_binding"] = {"kind":"typed_record"}
                elif mutation == "tail_hash": out["source_binding"]["sha256"] = "0" * 64
                elif mutation == "tail_bounds": out["source_binding"]["offset"] += 1
                self.sign()
                with self.subTest(owner=owner, mutation=mutation), self.assertRaises((ValueError, KeyError)):
                    self.run_audit()

    def test_v5_report_fingerprints_remain_unchanged_after_shared_helper_extraction(self):
        self.observed_guard_profile()
        self.assertEqual(self.run_audit()["payload_sha256"],
            "54d73fa66c2a3cac27c5e94182f2e5ebc937d854cc90291646b075945720e750")
        self.setUp()
        self.observed_guard_profile(opaque=True, choices=True)
        self.add_bypass()
        self.assertEqual(self.run_audit()["payload_sha256"],
            "b6feef0edf1686787edc910cbf8036c1628fc413cc3fa66015c72641e0faac1f")

    def test_original_bound_report_reproduces_without_certifying_execution(self):
        report = self.run_audit()
        self.assertEqual(report, self.run_audit())
        self.assertEqual(report["payload_sha256"], fingerprint(report))
        self.assertEqual(report["qualification"], "exact_source_records_only_runtime_witnesses_pending")
        self.assertTrue(all(row["producer"] == "python_phase1_4" for row in report["handoffs"].values()))

    def test_legacy_report_fingerprints_remain_unchanged(self):
        self.assertEqual(self.run_audit()["payload_sha256"],
            "8412c4221c31d349a94bebbf63f5cbb973386dcfc193e72760fba15e6f2b6425")
        self.continuation_profile()
        self.assertEqual(self.run_audit()["payload_sha256"],
            "af36e441a21169a4e73947fa72c1928b3a64e18eae7a49fda9006447d725a5b7")
        self.setUp()
        self.observation_profile()
        self.assertEqual(self.run_audit()["payload_sha256"],
            "c4686a0b87ad624645c3691db632be208eedc0961ae82b67e4b1d37f7361b58d")

    def test_source_coordinate_or_semantic_outcome_mutations_are_rejected(self):
        original = deepcopy(self.profile)
        for owner,key,value in [("guard","offset",1),("guard","end",1),("guard","false_target",1),
                                ("guard","prefix_sha256","0"*64),("caller","end",1),("caller","command",14),
                                ("outcome","end",2),("outcome","status","def_selection_boundary"),
                                ("callee","offset",1)]:
            self.profile = deepcopy(original)
            self.profile["routes"][0][owner][key] = value
            self.sign()
            with self.subTest(owner=owner,key=key), self.assertRaises((ValueError,KeyError)): self.run_audit()

    def test_tampered_schema_identity_and_witnesses_fail_closed(self):
        original = deepcopy(self.profile)
        for mutation in ("schema","hash","archive","entry","duplicate","empty","write","truth"):
            self.profile = deepcopy(original)
            route = self.profile["routes"][0]
            if mutation == "schema": self.profile["schema"] = "unknown/v2"
            elif mutation == "hash": self.profile["payload_sha256"] = "0"*64
            elif mutation == "archive": self.profile["archive_sha256"] = "0"*64
            elif mutation == "entry": self.profile["source_members"][0]["entry_sha256"] = "0"*64
            elif mutation == "duplicate": self.profile["routes"].append(deepcopy(route))
            elif mutation == "empty": route["variants"] = []
            elif mutation == "write": route["guard_cases"][1]["writes"][0]["value"] = 256
            elif mutation == "truth": route["guard_cases"][1]["expected"] = 2
            if mutation != "hash": self.sign()
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): self.run_audit()

    def continuation_profile(self):
        # An authored caller with a strict opaque tail containing an observed
        # handoff. The source audit must preserve that opaque classification.
        old = self.arc.read_bytes()
        caller_size = self.entries[0][2]
        handoff = b"\x0e\x01MACHI.MES\0\0"
        prefix = old[:caller_size - 1] + b"\x1f\0\0\0\0"
        opaque = b"\x08\xff" + handoff
        caller, callee = prefix + opaque, old[caller_size:]
        self.arc.write_bytes(caller + callee)
        self.entries = [("CALLER.MES",0,len(caller)),("QA.MES",len(caller),len(callee))]
        self.profile["schema"] = V2_SCHEMA
        self.profile["archive_sha256"] = hashlib.sha256(caller + callee).hexdigest()
        self.profile["source_members"][0]["entry_sha256"] = hashlib.sha256(caller).hexdigest()
        route = self.profile["routes"][0]
        start, at, end = len(prefix)-4, len(prefix)-2, len(caller)-4
        route.update(state_context={"kind":"fresh"}, choice_contracts=[],
            resume={"start":route["caller"]["end"], "message_count":0, "expected_state":[],
                "outcome":{"offset":at,"end":end,"op":"script_handoff_marker","status":"script_handoff_boundary","target":"MACHI.MES",
                    "record_sha256":hashlib.sha256(handoff).hexdigest(),
                    "source_binding":{"kind":"runtime_observation_in_opaque_tail","offset":start,"end":end,"sha256":hashlib.sha256(opaque).hexdigest()}}},
            reentry={"outcome":deepcopy(route["outcome"]),"message_count":0,"expected_state":[]})
        route["variants"][0].update(selections=[],expected_state=[],expected_resume_state=[],message_count=0)
        self.sign()

    def test_continuation_keeps_opaque_observations_separate_from_typed_source(self):
        self.continuation_profile()
        report = self.run_audit()
        self.assertEqual(report["schema"], "kakyu_event_analysis_group_source_audit/v2")
        self.assertEqual(report["qualification"], "typed_source_records_and_opaque_observation_bytes_runtime_witnesses_pending")
        self.assertEqual(report, self.run_audit())

    def test_continuation_mutations_fail_closed(self):
        self.continuation_profile()
        original = deepcopy(self.profile)
        for mutation in ("context", "calendar", "resume", "tail", "tail_hash", "record", "target", "reentry", "selection", "state", "count"):
            self.profile = deepcopy(original)
            route = self.profile["routes"][0]
            out = route["resume"]["outcome"]
            if mutation == "context": route["state_context"]["kind"] = "invented"
            elif mutation == "calendar": route["state_context"] = {"kind":"original_calendar","entry":"START.MES","table_sha256":"0"*64}
            elif mutation == "resume": route["resume"]["start"] += 1
            elif mutation == "tail": out["source_binding"]["kind"] = "typed"
            elif mutation == "tail_hash": out["source_binding"]["sha256"] = "0"*64
            elif mutation == "record": out["offset"] += 1
            elif mutation == "target": out["target"] = "QA.MES"
            elif mutation == "reentry": route["reentry"]["outcome"]["end"] += 1
            elif mutation == "selection": route["variants"][0]["selections"] = [{"boundary_offset":0,"result_value":1}]
            elif mutation == "state": route["variants"][0]["expected_resume_state"] = [{"storage":"global_u8","bank":0,"index":1,"value":256}]
            elif mutation == "count": route["variants"][0]["message_count"] = -1
            self.sign()
            with self.subTest(mutation=mutation), self.assertRaises((ValueError, KeyError)): self.run_audit()

    def observation_profile(self, command=15, target="NEXT.MES", opaque=False):
        old = self.arc.read_bytes()
        caller_size = self.entries[0][2]
        transition = bytes([command, 1]) + target.encode("ascii") + b"\0\0"
        prefix = old[:caller_size - 1] + b"\x1f\0\0\0\0"
        tail = (b"\x08\xff" if opaque else b"") + transition
        caller, callee = prefix + tail, old[caller_size:]
        self.arc.write_bytes(caller + callee)
        self.entries = [("CALLER.MES",0,len(caller)),("QA.MES",len(caller),len(callee))]
        self.profile["schema"] = V3_SCHEMA
        self.profile["archive_sha256"] = hashlib.sha256(caller + callee).hexdigest()
        self.profile["source_members"][0]["entry_sha256"] = hashlib.sha256(caller).hexdigest()
        route = self.profile["routes"][0]
        at, end = len(prefix) - 4 + (2 if opaque else 0), len(caller) - 4
        binding = ({"kind":"runtime_observation_in_opaque_tail", "offset":len(prefix)-4,
                    "end":end, "sha256":hashlib.sha256(tail).hexdigest()}
                   if opaque else {"kind":"typed_record"})
        route.update(qualification="caller_continuation_observation",
            state_context={"kind":"fresh"}, choice_contracts=[],
            resume={"start":route["caller"]["end"], "message_count":0, "expected_state":[],
                "boundary_policy":"stop_before_unprovided_dependency" if command == 15 else "natural_handoff",
                "outcome":{"offset":at,"end":end,"target":target,
                    "op":"script_dispatch" if command == 15 else "script_handoff_marker",
                    "status":"script_dispatch_boundary" if command == 15 else "script_handoff_boundary",
                    "record_sha256":hashlib.sha256(transition).hexdigest(), "source_binding":binding}},
            # Counts are runtime witness expectations; the source audit must
            # neither assert them nor force a zero-message completion claim.
            reentry={"outcome":deepcopy(route["outcome"]),"message_count":3,"expected_state":[]})
        route["variants"][0].update(selections=[],expected_state=[],expected_resume_state=[],message_count=0)
        self.sign()

    def test_v3_typed_dependency_stop_is_source_bound_without_completion_claim(self):
        self.observation_profile()
        report = self.run_audit()
        self.assertEqual(report["schema"], "kakyu_event_analysis_group_source_audit/v3")
        self.assertEqual(report["qualification"],
            "typed_source_records_or_opaque_observation_bytes_runtime_witnesses_pending_no_completion_claim")
        self.assertEqual(report["payload_sha256"], fingerprint(report))
        self.assertEqual(report, self.run_audit())
        self.assertEqual(report["profile"]["routes"][0]["reentry"]["message_count"], 3)

    def test_v3_typed_natural_handoff_allows_a_supplied_target(self):
        self.observation_profile(command=14, target="QA.MES")
        self.assertTrue(self.run_audit()["ok"])

    def test_v3_opaque_dependency_stop_keeps_its_opaque_binding(self):
        self.observation_profile(opaque=True)
        report = self.run_audit()
        self.assertEqual(report["profile"]["routes"][0]["resume"]["outcome"]["source_binding"]["kind"],
                         "runtime_observation_in_opaque_tail")
        self.profile["routes"][0]["resume"]["outcome"]["source_binding"] = {"kind":"typed_record"}
        self.sign()
        with self.assertRaises(ValueError): self.run_audit()

    def test_v3_opaque_natural_handoff_preserves_source_classification(self):
        self.observation_profile(command=14, opaque=True)
        self.assertTrue(self.run_audit()["ok"])
        self.profile["schema"] = V2_SCHEMA
        self.sign()
        self.assertEqual(self.run_audit()["schema"], "kakyu_event_analysis_group_source_audit/v2")

    def test_v3_dispatch_stop_rejects_a_supplied_dependency(self):
        # QA.MES exists in both the archive and source_members. Its bytes and
        # declared dispatch target match, so only the stop policy rejects it.
        self.observation_profile(target="QA.MES")
        with self.assertRaisesRegex(ValueError, "absent from source members"):
            self.run_audit()

    def test_v3_observation_qualification_policy_and_typed_boundaries_fail_closed(self):
        self.observation_profile()
        original = deepcopy(self.profile)
        for mutation in ("qualification_missing", "qualification", "policy_missing", "policy", "handoff_policy",
                         "status", "offset", "offset_fraction", "end", "op", "hash", "target", "binding", "reentry"):
            self.profile = deepcopy(original)
            route = self.profile["routes"][0]
            out = route["resume"]["outcome"]
            if mutation == "qualification_missing": del route["qualification"]
            elif mutation == "qualification": route["qualification"] = "completed_route"
            elif mutation == "policy_missing": del route["resume"]["boundary_policy"]
            elif mutation == "policy": route["resume"]["boundary_policy"] = "skip_dependency"
            elif mutation == "handoff_policy": route["resume"]["boundary_policy"] = "natural_handoff"
            elif mutation == "status": out["status"] = "script_return"
            elif mutation == "offset": out["offset"] += 1
            elif mutation == "offset_fraction": out["offset"] += 0.5
            elif mutation == "end": out["end"] -= 1
            elif mutation == "op": out["op"] = "script_handoff_marker"
            elif mutation == "hash": out["record_sha256"] = "0" * 64
            elif mutation == "target": out["target"] = "CHANGED.MES"
            elif mutation == "binding": out["source_binding"] = {"kind":"unknown"}
            elif mutation == "reentry": route["reentry"]["outcome"]["status"] = "completed_route"
            self.sign()
            with self.subTest(mutation=mutation), self.assertRaises((ValueError, KeyError)):
                self.run_audit()

    def append_reentry_choice(self, selector=40):
        # The source auditor checks exact records only. Execution reachability
        # and message observations remain the runtime validator's obligation.
        archive = self.arc.read_bytes() + bytes([0x1D, 2, selector, 0xFF, 0, 0])
        self.arc.write_bytes(archive)
        name, offset, size = self.entries[1]
        self.entries[1] = (name, offset, size + 6)
        self.profile["archive_sha256"] = hashlib.sha256(archive).hexdigest()
        self.profile["source_members"][1]["entry_sha256"] = hashlib.sha256(archive[offset:]).hexdigest()
        return {"outcome":{"offset":1,"end":6,"op":"script_transfer","status":"def_selection_boundary"},
                "message_count":4,"expected_state":[]}

    def test_v3_reentry_selection_and_variant_return_override_are_exact_source_observations(self):
        self.observation_profile()
        route = self.profile["routes"][0]
        returned = deepcopy(route["reentry"])
        route["reentry"] = self.append_reentry_choice()
        variant = deepcopy(route["variants"][0])
        variant.update(variant_id="returning-reentry", reentry=returned)
        route["variants"].append(variant)
        self.sign()
        report = self.run_audit()
        self.assertEqual(report, self.run_audit())
        self.assertEqual(report["profile"]["routes"][0]["reentry"]["outcome"]["status"], "def_selection_boundary")
        self.assertEqual(report["profile"]["routes"][0]["variants"][1]["reentry"], returned)
        self.assertIn("no_completion_claim", report["qualification"])

    def test_v3_variant_reentry_selection_override_is_checked_independently(self):
        self.observation_profile()
        self.profile["routes"][0]["variants"][0]["reentry"] = self.append_reentry_choice()
        self.sign()
        self.assertTrue(self.run_audit()["ok"])
        original = deepcopy(self.profile)
        for mutation in ("missing_outcome", "missing_count", "missing_state", "offset", "end", "op", "status",
                         "return_as_selection", "fraction", "count", "count_type", "write"):
            self.profile = deepcopy(original)
            reentry = self.profile["routes"][0]["variants"][0]["reentry"]
            if mutation == "missing_outcome": del reentry["outcome"]
            elif mutation == "missing_count": del reentry["message_count"]
            elif mutation == "missing_state": del reentry["expected_state"]
            elif mutation == "offset": reentry["outcome"]["offset"] += 1
            elif mutation == "end": reentry["outcome"]["end"] += 1
            elif mutation == "op": reentry["outcome"]["op"] = "command_00"
            elif mutation == "status": reentry["outcome"]["status"] = "completed_route"
            elif mutation == "return_as_selection": reentry["outcome"].update(offset=0,end=1,op="command_00")
            elif mutation == "fraction": reentry["outcome"]["offset"] += 0.5
            elif mutation == "count": reentry["message_count"] = -1
            elif mutation == "count_type": reentry["message_count"] = True
            elif mutation == "write": reentry["expected_state"] = [{"storage":"global_u8","bank":0,"index":1,"value":256}]
            self.sign()
            with self.subTest(mutation=mutation), self.assertRaises((ValueError, KeyError)):
                self.run_audit()

    def test_reentry_selection_requires_routine40_and_remains_unsupported_in_v2(self):
        self.observation_profile(command=14, opaque=True)
        self.profile["routes"][0]["reentry"] = self.append_reentry_choice(selector=39)
        self.sign()
        with self.assertRaisesRegex(ValueError, "routine-40"):
            self.run_audit()
        archive = bytearray(self.arc.read_bytes())
        archive[self.entries[1][1] + 7] = 40
        self.arc.write_bytes(archive)
        self.profile["archive_sha256"] = hashlib.sha256(archive).hexdigest()
        self.profile["source_members"][1]["entry_sha256"] = hashlib.sha256(archive[self.entries[1][1]:]).hexdigest()
        self.sign()
        self.assertTrue(self.run_audit()["ok"])
        self.profile["schema"] = V2_SCHEMA
        self.sign()
        with self.assertRaisesRegex(ValueError, "exact return record"):
            self.run_audit()

    def chained_profile(self, *, opaque_caller=False, choices=False):
        def choice_prefix(marker):
            code = b"\x1f" + struct.pack("<I", marker)
            definition = len(code)
            body, end = definition + 9, definition + 10
            code += b"\x10\x02\0\xff\0" + struct.pack("<I", end) + b"\0"
            boundary = len(code)
            code += b"\x1d\x02\x28\xff\0"
            return code, {"schema":"kakyu_mes_routine40_choice_contract/v3",
                "boundary_offset":boundary, "resume_offset":len(code), "definition_count":1,
                "result_values":[1], "definitions":[{"source_offset":definition, "body_offset":body,
                    "target_offset":end, "definition_id":0, "body_size":1,
                    "body_sha256":hashlib.sha256(b"\0").hexdigest()}]}

        caller_code, caller_contract = choice_prefix(0)
        callee_code, callee_contract = choice_prefix(1)
        if not choices:
            caller_code, callee_code = caller_code[:5], b""
        guard_at = len(caller_code)
        condition = bytes([0xF3, 1, 0, 0, 0xEF, 0xFF])
        guard_end = guard_at + 1 + len(condition) + 4
        gap = b"\x08\xff" if opaque_caller else b""
        dispatch = b"\x0f\x01QA.MES\0\0"
        at, end = guard_end + len(gap), guard_end + len(gap) + len(dispatch)
        caller_code += b"\x0b" + condition + struct.pack("<I", end) + gap + dispatch
        caller_code += b"\x1f\0\0\0\0"
        transition = b"\x0e\x01MACHI.MES\0\0"
        transition_at = len(caller_code)
        caller_code += transition
        callee_return = len(callee_code)
        callee_code += b"\0"
        caller, callee = b"\0" * 4 + caller_code, b"\0" * 4 + callee_code
        self.arc.write_bytes(caller + callee)
        self.entries = [("CALLER.MES", 0, len(caller)), ("QA.MES", len(caller), len(callee))]
        self.profile["schema"] = V4_SCHEMA
        self.profile["archive_sha256"] = hashlib.sha256(caller + callee).hexdigest()
        self.profile["source_members"] = [{"entry":name, "entry_sha256":hashlib.sha256(payload).hexdigest()}
            for name, payload in (("CALLER.MES", caller), ("QA.MES", callee))]
        binding = ({"kind":"runtime_observation_in_opaque_tail", "offset":guard_end,
                    "end":len(caller_code), "sha256":hashlib.sha256(caller_code[guard_end:]).hexdigest()}
                   if opaque_caller else {"kind":"typed_record"})
        route = self.profile["routes"][0]
        route["caller"].update(offset=at, end=end, source_binding=deepcopy(binding),
                               record_sha256=hashlib.sha256(dispatch).hexdigest())
        route["guard"].update(offset=guard_at, end=guard_end, false_target=end,
                              prefix_sha256=hashlib.sha256(caller_code[:end]).hexdigest())
        route["outcome"].update(offset=callee_return, end=callee_return + 1)
        route.update(origin_offset=0, qualification="caller_continuation_observation",
            state_context={"kind":"fresh"}, choice_contracts=[],
            resume={"start":end, "message_count":0, "expected_state":[], "boundary_policy":"natural_handoff",
                "outcome":{"offset":transition_at, "end":len(caller_code), "target":"MACHI.MES",
                    "op":"script_handoff_marker", "status":"script_handoff_boundary",
                    "record_sha256":hashlib.sha256(transition).hexdigest(), "source_binding":deepcopy(binding)}},
            reentry={"outcome":deepcopy(route["outcome"]), "message_count":0, "expected_state":[]})
        selections = []
        if choices:
            for owner, code, contract in (("CALLER.MES", caller_code, caller_contract),
                                          ("QA.MES", callee_code, callee_contract)):
                contract.update(source_identity={"archive":"mes.arc", "entry":owner},
                                bytecode_sha256=hashlib.sha256(code).hexdigest(), code_size=len(code))
                route["choice_contracts"].append(contract)
                selections.append({"owner_entry":owner, "boundary_offset":contract["boundary_offset"], "result_value":1})
        route["variants"][0].update(selections=selections, expected_state=[], expected_resume_state=[], message_count=0)
        self.sign()

    def test_v4_typed_origin_and_dispatch_preserve_no_completion_qualification(self):
        self.chained_profile()
        report = self.run_audit()
        self.assertEqual(report["schema"], "kakyu_event_analysis_group_source_audit/v4")
        self.assertIn("no_completion_claim", report["qualification"])
        self.assertEqual(report, self.run_audit())
        self.assertEqual(report["payload_sha256"], fingerprint(report))
        self.assertLess(report["profile"]["routes"][0]["origin_offset"],
                        report["profile"]["routes"][0]["guard"]["offset"])

    def test_v4_opaque_caller_and_resume_keep_source_classification(self):
        self.chained_profile(opaque_caller=True)
        report = self.run_audit()
        route = report["profile"]["routes"][0]
        self.assertEqual(route["caller"]["source_binding"]["kind"], "runtime_observation_in_opaque_tail")
        self.assertEqual(route["resume"]["start"], route["caller"]["end"])
        self.assertEqual(report, self.run_audit())
        route["caller"]["source_binding"] = {"kind":"typed_record"}
        self.sign()
        with self.assertRaises(ValueError): self.run_audit()

    def test_v4_origin_dispatch_and_opaque_binding_mutations_fail_closed(self):
        self.chained_profile(opaque_caller=True)
        original = deepcopy(self.profile)
        for mutation in ("origin_missing", "origin_fraction", "origin_bool", "origin_negative", "origin_operand",
                         "origin_after_guard", "origin_in_opaque_tail", "prefix_from_guard", "binding_missing",
                         "binding_kind", "binding_hash", "binding_bounds", "dispatch_hash_missing", "dispatch_hash",
                         "dispatch_offset", "dispatch_end", "dispatch_command", "resume_start"):
            self.profile = deepcopy(original)
            route = self.profile["routes"][0]
            caller = route["caller"]
            if mutation == "origin_missing": del route["origin_offset"]
            elif mutation == "origin_fraction": route["origin_offset"] = 0.5
            elif mutation == "origin_bool": route["origin_offset"] = False
            elif mutation == "origin_negative": route["origin_offset"] = -1
            elif mutation == "origin_operand": route["origin_offset"] = 1
            elif mutation == "origin_after_guard": route["origin_offset"] = caller["end"]
            elif mutation == "origin_in_opaque_tail": route["origin_offset"] = caller["offset"]
            elif mutation == "prefix_from_guard":
                code = self.arc.read_bytes()[4:self.entries[0][2]]
                route["guard"]["prefix_sha256"] = hashlib.sha256(code[route["guard"]["offset"]:caller["end"]]).hexdigest()
            elif mutation == "binding_missing": del caller["source_binding"]
            elif mutation == "binding_kind": caller["source_binding"] = {"kind":"typed_record"}
            elif mutation == "binding_hash": caller["source_binding"]["sha256"] = "0" * 64
            elif mutation == "binding_bounds": caller["source_binding"]["offset"] += 1
            elif mutation == "dispatch_hash_missing": del caller["record_sha256"]
            elif mutation == "dispatch_hash": caller["record_sha256"] = "0" * 64
            elif mutation == "dispatch_offset": caller["offset"] += 1
            elif mutation == "dispatch_end": caller["end"] -= 1
            elif mutation == "dispatch_command": caller["command"] = 14
            elif mutation == "resume_start": route["resume"]["start"] += 1
            self.sign()
            with self.subTest(mutation=mutation), self.assertRaises((ValueError, KeyError)):
                self.run_audit()

    def test_v4_same_choice_offset_in_different_owners_is_source_bound(self):
        self.chained_profile(opaque_caller=True, choices=True)
        report = self.run_audit()
        selections = report["profile"]["routes"][0]["variants"][0]["selections"]
        self.assertEqual(selections[0]["boundary_offset"], selections[1]["boundary_offset"])
        self.assertNotEqual(selections[0]["owner_entry"], selections[1]["owner_entry"])
        self.assertEqual(report, self.run_audit())

    def test_v4_choice_ownership_and_exact_selection_set_fail_closed(self):
        self.chained_profile(choices=True)
        original = deepcopy(self.profile)
        for mutation in ("contract_owner", "contract_archive", "contract_swap", "contract_duplicate", "contract_hash",
                         "definition_hash", "selection_owner_missing", "selection_owner", "selection_duplicate",
                         "selection_missing", "selection_extra", "selection_value", "selection_bool"):
            self.profile = deepcopy(original)
            route = self.profile["routes"][0]
            contracts = route["choice_contracts"]
            selections = route["variants"][0]["selections"]
            if mutation == "contract_owner": contracts[0]["source_identity"]["entry"] = "ABSENT.MES"
            elif mutation == "contract_archive": contracts[0]["source_identity"]["archive"] = "other.arc"
            elif mutation == "contract_swap": contracts[0]["source_identity"]["entry"] = "QA.MES"
            elif mutation == "contract_duplicate": contracts.append(deepcopy(contracts[0]))
            elif mutation == "contract_hash": contracts[0]["bytecode_sha256"] = contracts[1]["bytecode_sha256"]
            elif mutation == "definition_hash": contracts[0]["definitions"][0]["body_sha256"] = "0" * 64
            elif mutation == "selection_owner_missing": del selections[0]["owner_entry"]
            elif mutation == "selection_owner": selections[0]["owner_entry"] = "ABSENT.MES"
            elif mutation == "selection_duplicate": selections[1] = deepcopy(selections[0])
            elif mutation == "selection_missing": selections.pop()
            elif mutation == "selection_extra": selections.append(deepcopy(selections[0]))
            elif mutation == "selection_value": selections[0]["result_value"] = 2
            elif mutation == "selection_bool": selections[0]["result_value"] = True
            self.sign()
            with self.subTest(mutation=mutation), self.assertRaises((ValueError, KeyError)):
                self.run_audit()

    def test_v6_choice_contract_is_audited_like_v5_and_a_later_schema_is_refused(self):
        # EP-12 TALK (2026-10-05, Core 0.372.0): the contract schema v6 adds `position_gates`
        # over v5. The audit accepts it, re-derives the sparse-catalog fields for it exactly as
        # for a v5 contract, and refuses a schema it does not know.
        self.chained_profile(choices=True)
        original = deepcopy(self.profile)
        for version in ("v5", "v6"):
            self.profile = deepcopy(original)
            for contract in self.profile["routes"][0]["choice_contracts"]:
                contract.update(schema=f"kakyu_mes_routine40_choice_contract/{version}",
                                catalog_form="contiguous", hidden_ids=[], hidden_gates=[])
            self.sign()
            with self.subTest(version=version):
                self.assertTrue(self.run_audit()["ok"])
                self.profile["routes"][0]["choice_contracts"][0]["catalog_form"] = "sparse"
                self.sign()
                with self.assertRaises(ValueError):
                    self.run_audit()
        self.profile = deepcopy(original)
        self.profile["routes"][0]["choice_contracts"][0]["schema"] = "kakyu_mes_routine40_choice_contract/v7"
        self.sign()
        with self.assertRaises(ValueError):
            self.run_audit()

    def add_bypass(self):
        route = self.profile["routes"][0]
        bypass = {"variant_id":"outer-bypass", "writes":[],
            "selections":deepcopy(route["variants"][0]["selections"]),
            "outcome":deepcopy(route["resume"]["outcome"]), "message_count":2,
            "expected_state":[{"storage":"global_u8", "bank":0, "index":1, "value":1}]}
        route["bypass_variants"] = [bypass]
        self.sign()
        return bypass

    def test_v4_bypasses_bind_typed_and_opaque_handoffs_without_certifying_execution(self):
        for opaque in (False, True):
            with self.subTest(opaque=opaque):
                self.chained_profile(opaque_caller=opaque, choices=True)
                bypass = self.add_bypass()
                report = self.run_audit()
                self.assertEqual(report, self.run_audit())
                self.assertEqual(report["profile"]["routes"][0]["bypass_variants"], [bypass])
                self.assertIn("runtime_witnesses_pending_no_completion_claim", report["qualification"])

    def test_v4_bypass_identity_binding_handoff_selection_and_observations_fail_closed(self):
        self.chained_profile(opaque_caller=True, choices=True)
        self.add_bypass()
        original = deepcopy(self.profile)
        for mutation in ("duplicate_normal", "duplicate_bypass", "wrong_tail", "typed_tail", "record_hash",
                         "offset", "offset_fraction", "end", "target", "empty_target", "status", "op",
                         "selection_missing", "selection_owner", "selection_value", "negative_count", "count_bool",
                         "missing_count", "missing_writes", "missing_expected_state", "state_write", "expected_state"):
            self.profile = deepcopy(original)
            route = self.profile["routes"][0]
            bypass = route["bypass_variants"][0]
            out = bypass["outcome"]
            if mutation == "duplicate_normal": bypass["variant_id"] = route["variants"][0]["variant_id"]
            elif mutation == "duplicate_bypass": route["bypass_variants"].append(deepcopy(bypass))
            elif mutation == "wrong_tail": out["source_binding"]["sha256"] = "0" * 64
            elif mutation == "typed_tail": out["source_binding"] = {"kind":"typed_record"}
            elif mutation == "record_hash": out["record_sha256"] = "0" * 64
            elif mutation == "offset": out["offset"] += 1
            elif mutation == "offset_fraction": out["offset"] += 0.5
            elif mutation == "end": out["end"] -= 1
            elif mutation == "target": out["target"] = "QA.MES"
            elif mutation == "empty_target": out["target"] = ""
            elif mutation == "status": out["status"] = "script_dispatch_boundary"
            elif mutation == "op": out["op"] = "script_dispatch"
            elif mutation == "selection_missing": bypass["selections"].pop()
            elif mutation == "selection_owner": bypass["selections"][0]["owner_entry"] = "ABSENT.MES"
            elif mutation == "selection_value": bypass["selections"][0]["result_value"] = 2
            elif mutation == "negative_count": bypass["message_count"] = -1
            elif mutation == "count_bool": bypass["message_count"] = False
            elif mutation == "missing_count": del bypass["message_count"]
            elif mutation == "missing_writes": del bypass["writes"]
            elif mutation == "missing_expected_state": del bypass["expected_state"]
            elif mutation == "state_write": bypass["writes"] = [{"storage":"global_u8", "bank":0, "index":1, "value":256}]
            elif mutation == "expected_state": bypass["expected_state"][0]["value"] = 256
            self.sign()
            with self.subTest(mutation=mutation), self.assertRaises((ValueError, KeyError)):
                self.run_audit()

    def test_v4_bypass_rejects_an_exact_dispatch_record_as_a_handoff(self):
        self.chained_profile()
        bypass = self.add_bypass()
        caller = self.profile["routes"][0]["caller"]
        bypass["outcome"] = {key:deepcopy(caller[key])
                             for key in ("offset", "end", "record_sha256", "source_binding")}
        bypass["outcome"].update(op="script_dispatch", target="QA.MES", status="script_handoff_boundary")
        self.sign()
        with self.assertRaisesRegex(ValueError, "exact handoff observation"):
            self.run_audit()

    def test_v4_preserves_variant_reentry_observation_overrides(self):
        self.chained_profile()
        self.profile["routes"][0]["variants"][0]["reentry"] = self.append_reentry_choice()
        self.sign()
        self.assertTrue(self.run_audit()["ok"])
        self.profile["routes"][0]["variants"][0]["reentry"]["outcome"]["end"] += 1
        self.sign()
        with self.assertRaises(ValueError): self.run_audit()

    def test_v4_report_fingerprints_remain_unchanged(self):
        self.chained_profile()
        self.assertEqual(self.run_audit()["payload_sha256"],
            "3264c8b561403ed8c9256fabb71fb1653aa273410acd962dee91db41a0888945")
        self.chained_profile(opaque_caller=True, choices=True)
        self.add_bypass()
        self.assertEqual(self.run_audit()["payload_sha256"],
            "6dcecb5a030eb8d321f5ee8ecba83593b79737db487407e88e6b40b57bf52274")

    def observed_guard_profile(self, *, opaque=False, choices=False):
        self.chained_profile(opaque_caller=opaque, choices=choices)
        self.profile["schema"] = V5_SCHEMA
        route = self.profile["routes"][0]
        caller, guard = route["caller"], route["guard"]
        archive = self.arc.read_bytes()
        caller_size = self.entries[0][2]
        code = archive[4:caller_size]
        if opaque:
            # Move the framing failure before the guard, preserving every
            # later caller coordinate. A runtime observation may decode this
            # exact branch, but the authoritative handoff must keep it opaque.
            tail_start = guard["offset"]
            code = code[:tail_start] + b"\x08\xff" + code[tail_start:guard["end"]] + code[guard["end"] + 2:]
            guard["offset"] += 2
            guard["end"] += 2
            payload = b"\0" * 4 + code
            archive = payload + archive[caller_size:]
            self.arc.write_bytes(archive)
            self.profile["archive_sha256"] = hashlib.sha256(archive).hexdigest()
            self.profile["source_members"][0]["entry_sha256"] = hashlib.sha256(payload).hexdigest()
            binding = {"kind":"runtime_observation_in_opaque_tail", "offset":tail_start,
                       "end":len(code), "sha256":hashlib.sha256(code[tail_start:]).hexdigest()}
            caller["source_binding"] = deepcopy(binding)
            route["resume"]["outcome"]["source_binding"] = deepcopy(binding)
            for contract in route["choice_contracts"]:
                if contract["source_identity"]["entry"] == caller["entry"]:
                    contract["bytecode_sha256"] = hashlib.sha256(code).hexdigest()
        else:
            binding = {"kind":"typed_record"}
        guard["source_binding"] = binding
        guard["record_sha256"] = hashlib.sha256(code[guard["offset"]:guard["end"]]).hexdigest()
        guard["prefix_sha256"] = hashlib.sha256(code[route["origin_offset"]:caller["end"]]).hexdigest()
        self.sign()

    def test_v5_typed_and_opaque_guard_observations_preserve_authority(self):
        for opaque in (False, True):
            with self.subTest(opaque=opaque):
                self.observed_guard_profile(opaque=opaque, choices=True)
                self.add_bypass()
                report = self.run_audit()
                self.assertEqual(report["schema"], "kakyu_event_analysis_group_source_audit/v5")
                self.assertIn("runtime_witnesses_pending_no_completion_claim", report["qualification"])
                self.assertEqual(report, self.run_audit())
                guard = self.profile["routes"][0]["guard"]
                branch_offsets = {branch["offset"] for branch in report["handoffs"]["CALLER.MES"]["branches"]}
                self.assertEqual(guard["offset"] in branch_offsets, not opaque)

    def test_v5_opaque_guard_mutations_fail_closed(self):
        self.observed_guard_profile(opaque=True)
        original = deepcopy(self.profile)
        for mutation in ("binding_missing", "hash_missing", "typed_binding", "tail_start", "tail_end", "tail_hash",
                         "record_hash", "guard_offset", "guard_end", "guard_fraction", "guard_bool", "false_target",
                         "origin_in_tail", "prefix_hash", "legacy_schema"):
            self.profile = deepcopy(original)
            route = self.profile["routes"][0]
            guard = route["guard"]
            if mutation == "binding_missing": del guard["source_binding"]
            elif mutation == "hash_missing": del guard["record_sha256"]
            elif mutation == "typed_binding": guard["source_binding"] = {"kind":"typed_record"}
            elif mutation == "tail_start": guard["source_binding"]["offset"] += 1
            elif mutation == "tail_end": guard["source_binding"]["end"] -= 1
            elif mutation == "tail_hash": guard["source_binding"]["sha256"] = "0" * 64
            elif mutation == "record_hash": guard["record_sha256"] = "0" * 64
            elif mutation == "guard_offset": guard["offset"] += 1
            elif mutation == "guard_end": guard["end"] -= 1
            elif mutation == "guard_fraction": guard["offset"] += 0.5
            elif mutation == "guard_bool": guard["offset"] = True
            elif mutation == "false_target": guard["false_target"] += 1
            elif mutation == "origin_in_tail": route["origin_offset"] = guard["offset"]
            elif mutation == "prefix_hash": guard["prefix_sha256"] = "0" * 64
            elif mutation == "legacy_schema": self.profile["schema"] = V4_SCHEMA
            self.sign()
            with self.subTest(mutation=mutation), self.assertRaises((ValueError, KeyError)):
                self.run_audit()

    def test_v5_guard_rejects_an_exact_nonpredicate_record(self):
        self.observed_guard_profile()
        route = self.profile["routes"][0]
        # The source marker at the typed origin has an exact valid hash and
        # bounds, but cannot stand in for an eligibility predicate.
        code = self.arc.read_bytes()[4:self.entries[0][2]]
        route["guard"].update(offset=0, end=5, record_sha256=hashlib.sha256(code[:5]).hexdigest())
        self.sign()
        with self.assertRaisesRegex(ValueError, "Exact guard or caller prefix differs"):
            self.run_audit()

    def test_v5_guard_predicate_bytes_cannot_change_under_an_old_record_hash(self):
        self.observed_guard_profile(opaque=True)
        route = self.profile["routes"][0]
        archive = bytearray(self.arc.read_bytes())
        # Change the original comparison literal 0 to 1 while refreshing the
        # archive, member, opaque-tail and prefix hashes. The old exact guard
        # record fingerprint must still reject this semantic alteration.
        archive[4 + route["guard"]["offset"] + 4] = 1
        self.arc.write_bytes(archive)
        caller_size = self.entries[0][2]
        code = archive[4:caller_size]
        self.profile["archive_sha256"] = hashlib.sha256(archive).hexdigest()
        self.profile["source_members"][0]["entry_sha256"] = hashlib.sha256(archive[:caller_size]).hexdigest()
        binding = route["guard"]["source_binding"]
        binding["sha256"] = hashlib.sha256(code[binding["offset"]:binding["end"]]).hexdigest()
        route["caller"]["source_binding"] = deepcopy(binding)
        route["resume"]["outcome"]["source_binding"] = deepcopy(binding)
        route["guard"]["prefix_sha256"] = hashlib.sha256(code[:route["caller"]["end"]]).hexdigest()
        self.sign()
        with self.assertRaisesRegex(ValueError, "Runtime observation record bytes differ"):
            self.run_audit()

    def def_selection_resume_profile(self):
        """A v5 route whose caller stops at a routine-40 selection, not a handoff."""
        self.observed_guard_profile()
        route = self.profile["routes"][0]
        archive = self.arc.read_bytes()
        caller_size = self.entries[0][2]
        callee = archive[caller_size:]
        code = archive[4:caller_size]
        stop_at = route["resume"]["outcome"]["offset"]
        selection = bytes([0x1D, 0x02, 0x28, 0xFF, 0x00])
        code = code[:stop_at] + selection
        caller = bytes(4) + code
        self.arc.write_bytes(caller + callee)
        self.entries = [("CALLER.MES", 0, len(caller)), ("QA.MES", len(caller), len(callee))]
        self.profile["schema"] = V8_SCHEMA
        self.profile["archive_sha256"] = hashlib.sha256(caller + callee).hexdigest()
        self.profile["source_members"][0]["entry_sha256"] = hashlib.sha256(caller).hexdigest()
        route["resume"]["boundary_policy"] = "def_selection_boundary"
        route["resume"]["outcome"].update(offset=stop_at, end=stop_at + len(selection),
            op="script_transfer", status="def_selection_boundary", target="",
            record_sha256=hashlib.sha256(selection).hexdigest())
        self.sign()

    def test_v8_binds_a_routine_40_caller_resume_boundary(self):
        self.def_selection_resume_profile()
        report = self.run_audit()
        self.assertEqual(report["schema"], "kakyu_event_analysis_group_source_audit/v8")
        self.assertIn("no_completion_claim", report["qualification"])
        self.assertEqual(report, self.run_audit())
        route = report["profile"]["routes"][0]
        self.assertEqual(route["resume"]["boundary_policy"], "def_selection_boundary")
        self.assertEqual(route["resume"]["start"], route["caller"]["end"])

    def test_v8_rejects_the_other_boundary_policies_for_this_record(self):
        for policy in ("natural_handoff", "stop_before_unprovided_dependency"):
            with self.subTest(policy=policy):
                self.def_selection_resume_profile()
                self.profile["routes"][0]["resume"]["boundary_policy"] = policy
                self.sign()
                with self.assertRaises(ValueError):
                    self.run_audit()

    def test_the_def_selection_policy_is_v8_only(self):
        self.def_selection_resume_profile()
        self.profile["schema"] = V5_SCHEMA
        self.sign()
        with self.assertRaisesRegex(ValueError, "Unsupported caller-continuation boundary policy"):
            self.run_audit()

    def test_v8_def_selection_declarations_fail_closed(self):
        self.def_selection_resume_profile()
        original = deepcopy(self.profile)
        mutations = {
            "named_target": lambda r: r["resume"]["outcome"].update(target="QA.MES"),
            "shifted_offset": lambda r: r["resume"]["outcome"].update(offset=r["resume"]["outcome"]["offset"] + 1),
            "shifted_end": lambda r: r["resume"]["outcome"].update(end=r["resume"]["outcome"]["end"] + 1),
            "handoff_op": lambda r: r["resume"]["outcome"].update(op="script_handoff_marker"),
            "return_status": lambda r: r["resume"]["outcome"].update(status="script_return"),
            "negative_offset": lambda r: r["resume"]["outcome"].update(offset=-1),
            "qualification": lambda r: r.update(qualification="root_replacement_observation"),
        }
        for name, mutate in mutations.items():
            with self.subTest(mutation=name):
                self.profile = deepcopy(original)
                mutate(self.profile["routes"][0])
                self.sign()
                with self.assertRaises(ValueError):
                    self.run_audit()

    def test_v8_requires_an_exact_routine_40_selection(self):
        self.def_selection_resume_profile()
        route = self.profile["routes"][0]
        archive = bytearray(self.arc.read_bytes())
        caller_size = self.entries[0][2]
        # The same command 0x1D envelope, naming a routine other than 40.
        archive[4 + route["resume"]["outcome"]["offset"] + 2] = 0x20
        self.arc.write_bytes(bytes(archive))
        caller = bytes(archive[:caller_size])
        self.profile["archive_sha256"] = hashlib.sha256(bytes(archive)).hexdigest()
        self.profile["source_members"][0]["entry_sha256"] = hashlib.sha256(caller).hexdigest()
        stop = route["resume"]["outcome"]
        stop["record_sha256"] = hashlib.sha256(caller[4 + stop["offset"]:4 + stop["end"]]).hexdigest()
        route["guard"]["prefix_sha256"] = hashlib.sha256(
            caller[4:4 + route["caller"]["end"]]).hexdigest()
        self.sign()
        with self.assertRaisesRegex(ValueError, "exact routine-40 record"):
            self.run_audit()

    def visits_profile(self):
        """A v13 route: v8's def-selection resume plus a two-visit chain, the
        second visit dispatching a third member (NESTED.MES)."""
        self.def_selection_resume_profile()
        route = self.profile["routes"][0]
        archive = self.arc.read_bytes()
        caller_size = self.entries[0][2]
        caller = archive[:caller_size]
        callee_old = archive[caller_size:]
        callee_header, callee_code = callee_old[:4], callee_old[4:]
        dispatch = b"\x0f\x01NESTED.MES\0\0"
        dispatch_offset = len(callee_code)
        callee_code = callee_code + dispatch
        callee = callee_header + callee_code
        nested = b"\0" * 4 + b"\0"
        self.arc.write_bytes(caller + callee + nested)
        self.entries = [("CALLER.MES", 0, len(caller)), ("QA.MES", len(caller), len(callee)),
                        ("NESTED.MES", len(caller) + len(callee), len(nested))]
        self.profile["schema"] = V13_SCHEMA
        self.profile["archive_sha256"] = hashlib.sha256(caller + callee + nested).hexdigest()
        self.profile["source_members"][1]["entry_sha256"] = hashlib.sha256(callee).hexdigest()
        self.profile["source_members"].append({"entry": "NESTED.MES", "entry_sha256": hashlib.sha256(nested).hexdigest()})
        self.dispatch_offset, self.dispatch_end = dispatch_offset, dispatch_offset + len(dispatch)
        route["visits"] = [
            {"visit_id": "v1", "after": "reentry", "entry_state": [], "seed_writes": [], "seed_basis": "none",
             "outcome": deepcopy(route["outcome"]), "message_count": 0, "expected_state": [], "dispatches": []},
            {"visit_id": "v2", "after": "v1",
             "entry_state": [{"storage": "global_u8", "bank": 0, "index": 5, "value": 0}],
             "seed_writes": [{"storage": "global_u8", "bank": 0, "index": 5, "value": 1}],
             "seed_basis": "tool_seeded", "outcome": deepcopy(route["outcome"]), "message_count": 0,
             "expected_state": [],
             "dispatches": [{"entry": "NESTED.MES", "offset": dispatch_offset, "end": self.dispatch_end,
                 "outcome": {"offset": 0, "end": 1, "op": "command_00", "status": "script_return"},
                 "message_count": 0}]},
        ]
        self.sign()

    def test_v13_binds_a_valid_visit_chain(self):
        self.visits_profile()
        report = self.run_audit()
        self.assertTrue(report.get("ok"), report)
        self.assertEqual(report["schema"], "kakyu_event_analysis_group_source_audit/v13")
        self.assertEqual(report, self.run_audit())
        self.assertEqual(len(report["profile"]["routes"][0]["visits"]), 2)

    def test_v13_is_v8_plus_visits_and_the_field_is_v13_only(self):
        self.visits_profile()
        self.profile["schema"] = V8_SCHEMA
        self.sign()
        with self.assertRaisesRegex(ValueError, "Visits need a V13 route"):
            self.run_audit()

    def test_v13_visit_chain_mutations_fail_closed(self):
        self.visits_profile()
        original = deepcopy(self.profile)
        mutations = {
            "unknown_after": lambda r: r["visits"][1].update(after="v9"),
            "forward_after": lambda r: r["visits"][0].update(after="v2"),
            "wrong_outcome": lambda r: r["visits"][0]["outcome"].update(end=r["visits"][0]["outcome"]["end"] + 1),
            "wrong_dispatch_offset": lambda r: r["visits"][1]["dispatches"][0].update(offset=self.dispatch_offset + 1),
            "dispatch_non_member": lambda r: r["visits"][1]["dispatches"][0].update(entry="GHOST.MES"),
            "missing_seed_basis": lambda r: r["visits"][1].pop("seed_basis"),
            "missing_entry_state": lambda r: r["visits"][0].pop("entry_state"),
            "malformed_entry_state_cell": lambda r: r["visits"][1].update(
                entry_state=[{"storage": "global_u8", "bank": 0, "index": 5}]),
        }
        for name, mutate in mutations.items():
            with self.subTest(mutation=name):
                self.profile = deepcopy(original)
                mutate(self.profile["routes"][0])
                self.sign()
                with self.assertRaises((ValueError, KeyError)):
                    self.run_audit()

    def caller_loop_resume_profile(self):
        """A v8-shaped route whose caller runs into its own loop: a message, its
        wait and a jump back to the message. The wait is the loop head."""
        self.observed_guard_profile()
        route = self.profile["routes"][0]
        archive = self.arc.read_bytes()
        caller_size = self.entries[0][2]
        callee = archive[caller_size:]
        code = archive[4:caller_size]
        stop_at = route["resume"]["outcome"]["offset"]
        message = bytes([0x01, 0x41, 0x00])
        wait = bytes([0x0D, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00])
        code = code[:stop_at] + message + wait + b"\x0c" + struct.pack("<I", stop_at)
        caller = bytes(4) + code
        self.arc.write_bytes(caller + callee)
        self.entries = [("CALLER.MES", 0, len(caller)), ("QA.MES", len(caller), len(callee))]
        self.profile["schema"] = V10_SCHEMA
        self.profile["archive_sha256"] = hashlib.sha256(caller + callee).hexdigest()
        self.profile["source_members"][0]["entry_sha256"] = hashlib.sha256(caller).hexdigest()
        head = stop_at + len(message)
        route["resume"]["boundary_policy"] = "caller_menu_loop"
        route["resume"]["outcome"].update(offset=head, end=head + len(wait), op="system_call",
            status="loop_boundary", target="", record_sha256=hashlib.sha256(wait).hexdigest())
        route["resume"]["loop"] = {"period": 1, "period_message_count": 1,
            "cycle": [{"entry": "CALLER.MES", "offset": head, "end": head + len(wait), "status": "dialogue_boundary"}]}
        self.sign()

    def test_v10_binds_a_caller_loop_resume_boundary(self):
        self.caller_loop_resume_profile()
        report = self.run_audit()
        self.assertEqual(report["schema"], "kakyu_event_analysis_group_source_audit/v10")
        self.assertIn("no_completion_claim", report["qualification"])
        self.assertEqual(report, self.run_audit())
        route = report["profile"]["routes"][0]
        self.assertEqual(route["resume"]["boundary_policy"], "caller_menu_loop")
        self.assertEqual(route["resume"]["loop"]["period"], 1)

    def test_v10_still_accepts_the_earlier_resume_policies(self):
        self.def_selection_resume_profile()
        self.profile["schema"] = V10_SCHEMA
        self.sign()
        self.assertEqual(self.run_audit()["schema"], "kakyu_event_analysis_group_source_audit/v10")

    def test_the_caller_loop_policy_is_v10_only(self):
        for schema in (V5_SCHEMA, V8_SCHEMA):
            with self.subTest(schema=schema):
                self.caller_loop_resume_profile()
                self.profile["schema"] = schema
                self.sign()
                with self.assertRaisesRegex(ValueError, "Unsupported caller-continuation boundary policy"):
                    self.run_audit()

    def test_v10_loop_declarations_fail_closed(self):
        self.caller_loop_resume_profile()
        original = deepcopy(self.profile)

        def cycle(r):
            return r["resume"]["loop"]["cycle"][0]

        mutations = {
            "named_target": lambda r: r["resume"]["outcome"].update(target="QA.MES"),
            "shifted_head": lambda r: (r["resume"]["outcome"].update(offset=r["resume"]["outcome"]["offset"] + 1),
                                       cycle(r).update(offset=cycle(r)["offset"] + 1)),
            "head_is_not_the_first_cycle_row": lambda r: cycle(r).update(offset=cycle(r)["offset"] - 3),
            "selection_status": lambda r: r["resume"]["outcome"].update(status="def_selection_boundary"),
            "period_without_rows": lambda r: r["resume"]["loop"].update(period=2),
            "zero_period": lambda r: (r["resume"]["loop"].update(period=0), r["resume"]["loop"].update(cycle=[])),
            "negative_period_messages": lambda r: r["resume"]["loop"].update(period_message_count=-1),
            "shifted_row_end": lambda r: cycle(r).update(end=cycle(r)["end"] + 1),
            "routine_status_on_a_wait": lambda r: cycle(r).update(status="shared_routine_boundary"),
            "unknown_row_status": lambda r: cycle(r).update(status="script_dispatch_boundary"),
            "foreign_row_entry": lambda r: cycle(r).update(entry="QA.MES"),
            "message_record_as_a_row": lambda r: (cycle(r).update(offset=cycle(r)["offset"] - 3, end=cycle(r)["offset"]),
                                                  r["resume"]["outcome"].update(offset=cycle(r)["offset"] - 3, end=cycle(r)["offset"])),
        }
        for name, mutate in mutations.items():
            with self.subTest(mutation=name):
                self.profile = deepcopy(original)
                mutate(self.profile["routes"][0])
                self.sign()
                with self.assertRaises(ValueError):
                    self.run_audit()

    MAP_POLL = map_location_poll()

    def add_map_member(self, poll=MAP_POLL):
        """A third member holding one Map.get_location poll and a return."""
        code = poll + b"\0"
        payload = bytes(4) + code
        archive = self.arc.read_bytes() + payload
        self.arc.write_bytes(archive)
        self.entries = self.entries + [("MAP.MES", len(archive) - len(payload), len(payload))]
        self.profile["archive_sha256"] = hashlib.sha256(archive).hexdigest()
        self.profile["source_members"].append({"entry": "MAP.MES", "entry_sha256": hashlib.sha256(payload).hexdigest()})
        return {"schema": "kakyu_mes_map_location_contract/v1", "source_identity": {"archive": "mes.arc", "entry": "MAP.MES"},
                "poll_offset": 0, "poll_end": len(poll), "poll_function": [6, 13],
                "record_sha256": hashlib.sha256(poll).hexdigest(), "result_storage": "state_u16",
                "result_index": 18, "none_value": 0xFFFF, "locations": [0, 1]}

    def map_location_root_profile(self):
        self.root_replacement_profile()
        contract = self.add_map_member()
        self.profile["schema"] = V11_SCHEMA
        self.profile["routes"][0]["map_location_contracts"] = [contract]
        self.sign()

    def map_location_continuation_profile(self):
        self.def_selection_resume_profile()
        contract = self.add_map_member()
        self.profile["schema"] = V12_SCHEMA
        self.profile["routes"][0]["map_location_contracts"] = [contract]
        self.sign()

    def test_v11_binds_map_location_contracts_on_a_root_replacement(self):
        self.map_location_root_profile()
        report = self.run_audit()
        self.assertEqual(report["schema"], "kakyu_event_analysis_group_source_audit/v11")
        self.assertEqual(report, self.run_audit())
        contract = report["profile"]["routes"][0]["map_location_contracts"][0]
        self.assertEqual((contract["poll_offset"], contract["locations"]), (0, [0, 1]))

    def test_v12_binds_map_location_contracts_on_a_continuation(self):
        self.map_location_continuation_profile()
        report = self.run_audit()
        self.assertEqual(report["schema"], "kakyu_event_analysis_group_source_audit/v12")
        self.assertEqual(report["profile"]["routes"][0]["resume"]["boundary_policy"], "def_selection_boundary")

    def test_map_location_contracts_need_v11_on_a_root_replacement(self):
        self.map_location_root_profile()
        self.profile["schema"] = V6_SCHEMA
        self.sign()
        with self.assertRaisesRegex(ValueError, "need a V11 or V12 route"):
            self.run_audit()

    def test_map_location_contracts_need_v12_on_a_continuation(self):
        self.map_location_continuation_profile()
        self.profile["schema"] = V10_SCHEMA
        self.sign()
        with self.assertRaisesRegex(ValueError, "need a V11 or V12 route"):
            self.run_audit()

    def test_a_map_location_schema_declares_at_least_one_contract(self):
        self.map_location_root_profile()
        del self.profile["routes"][0]["map_location_contracts"]
        self.sign()
        with self.assertRaisesRegex(ValueError, "declares at least one map-location contract"):
            self.run_audit()

    def test_map_location_declarations_fail_closed(self):
        self.map_location_root_profile()
        original = deepcopy(self.profile)

        def contract(r):
            return r["map_location_contracts"][0]

        mutations = {
            "foreign_entry": lambda r: contract(r)["source_identity"].update(entry="QA.MES"),
            "contract_schema": lambda r: contract(r).update(schema="kakyu_mes_map_location_contract/v2"),
            "shifted_poll": lambda r: contract(r).update(poll_offset=1),
            "shifted_end": lambda r: contract(r).update(poll_end=contract(r)["poll_end"] + 1),
            "wrong_hash": lambda r: contract(r).update(record_sha256="0" * 64),
            "other_function": lambda r: contract(r).update(poll_function=[6, 12]),
            "other_cell": lambda r: contract(r).update(result_index=19),
            "other_storage": lambda r: contract(r).update(result_storage="banked_u16"),
            "other_none": lambda r: contract(r).update(none_value=0),
            "no_locations": lambda r: contract(r).update(locations=[]),
            "location_out_of_range": lambda r: contract(r).update(locations=[0, 70000]),
            "location_is_none": lambda r: contract(r).update(locations=[0xFFFF]),
            "spent_by_empty": lambda r: contract(r).update(spent_by=[]),
            "spent_by_unknown_run": lambda r: contract(r).update(spent_by=["whole", "never"]),
            "spent_by_without_unbroken": lambda r: contract(r).update(spent_by=["callee"]),
            "spent_by_unbroken_only": lambda r: contract(r).update(spent_by=["whole"]),
            "spent_by_resume_on_a_root_replacement": lambda r: contract(r).update(spent_by=["resume", "whole"]),
            "spent_by_repeated": lambda r: contract(r).update(spent_by=["callee", "callee", "whole"]),
        }
        for name, mutate in mutations.items():
            with self.subTest(mutation=name):
                self.profile = deepcopy(original)
                mutate(self.profile["routes"][0])
                self.sign()
                with self.assertRaises(ValueError):
                    self.run_audit()

    def test_an_arrival_contract_is_spent_by_the_prefix(self):
        # 0.319.0: the caller's own arrival poll is spent by the prefix run;
        # a contract that declares nothing keeps the callee run.
        self.map_location_root_profile()
        self.profile["routes"][0]["map_location_contracts"][0]["spent_by"] = ["prefix", "whole"]
        self.sign()
        self.assertEqual(self.run_audit()["profile"]["routes"][0]["map_location_contracts"][0]["spent_by"], ["prefix", "whole"])

    def test_a_way_out_contract_is_spent_by_the_resume(self):
        self.map_location_continuation_profile()
        self.profile["routes"][0]["map_location_contracts"][0]["spent_by"] = ["resume", "whole"]
        self.sign()
        self.assertEqual(self.run_audit()["profile"]["routes"][0]["map_location_contracts"][0]["spent_by"], ["resume", "whole"])

    def test_map_location_poll_must_be_get_location(self):
        # The same command-0x12 envelope naming Util(6,12) instead of Util(6,13),
        # with every hash refreshed: the record is not Map.get_location.
        self.root_replacement_profile()
        contract = self.add_map_member(bytes([0x12, 0x02, 0x06, 0xFF, 0x02, 0x0C, 0xFF, 0x00]))
        self.profile["schema"] = V11_SCHEMA
        self.profile["routes"][0]["map_location_contracts"] = [contract]
        self.sign()
        with self.assertRaisesRegex(ValueError, "exact Map.get_location record"):
            self.run_audit()

    def test_v8_post_guard_expected_is_accepted_at_route_level(self):
        # 0.315.0: a caller-continuation route (V5, V8) may declare its
        # post-guard truth, checked with V6's own type rule.
        self.def_selection_resume_profile()
        route = self.profile["routes"][0]
        route["post_guard_expected"] = 1
        self.sign()
        self.assertTrue(self.run_audit()["ok"])
        for value in (True, False, -1, 2, 0.0, "0"):
            self.profile["routes"][0]["post_guard_expected"] = value
            self.sign()
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.run_audit()
        # A handful of already-shipped V8 profiles carry a route-level
        # post_guard_expected: null placeholder from before this field had
        # any meaning here; null must stay absent, not a declared 0/1, so
        # every existing profile is unchanged.
        self.profile["routes"][0]["post_guard_expected"] = None
        self.sign()
        self.assertTrue(self.run_audit()["ok"])

    def test_v8_post_guard_expected_variant_override_is_accepted(self):
        self.def_selection_resume_profile()
        route = self.profile["routes"][0]
        route["post_guard_expected"] = 1
        route["variants"][0]["post_guard_expected"] = 0
        self.sign()
        report = self.run_audit()
        self.assertTrue(report["ok"])
        self.assertEqual(report["profile"]["routes"][0]["variants"][0]["post_guard_expected"], 0)
        route["variants"][0]["post_guard_expected"] = 2
        self.sign()
        with self.assertRaises(ValueError):
            self.run_audit()

    def test_v8_variant_reentry_override_is_source_bound(self):
        self.def_selection_resume_profile()
        route = self.profile["routes"][0]
        variant = deepcopy(route["variants"][0])
        variant.update(variant_id="reentry-override", reentry=self.append_reentry_choice())
        route["variants"].append(variant)
        self.sign()
        report = self.run_audit()
        self.assertTrue(report["ok"])
        self.assertEqual(report, self.run_audit())
        self.assertEqual(report["profile"]["routes"][0]["variants"][1]["reentry"]["outcome"]["status"],
            "def_selection_boundary")

    def unconditional_continuation_profile(self, *, escaping=False):
        """A v9 caller: v7's unguarded window in front of a nested call (command
        15) whose callee returns and whose caller resumes, v8/v5's shape."""
        route = self.profile["routes"][0]
        condition = bytes([0xF3, 1, 0, 0, 0xEF, 0xFF])  # global_u8[1] == 0
        head = bytes([0x0B]) + condition
        dispatch = bytes([0x0F, 0x01]) + b"QA.MES" + bytes([0, 0])
        branch_size = len(head) + 4
        target = branch_size + len(dispatch) if escaping else branch_size
        handoff = bytes([0x0E, 0x01]) + b"MACHI.MES" + bytes([0, 0])
        caller_code = head + struct.pack("<I", target) + dispatch + handoff
        caller = bytes(4) + caller_code
        callee = bytes(4) + bytes([0])
        archive = caller + callee
        self.arc.write_bytes(archive)
        self.entries = [("CALLER.MES", 0, len(caller)), ("QA.MES", len(caller), len(callee))]
        self.profile["schema"] = V9_SCHEMA
        self.profile["archive_sha256"] = hashlib.sha256(archive).hexdigest()
        self.profile["source_members"] = [
            {"entry": "CALLER.MES", "entry_sha256": hashlib.sha256(caller).hexdigest()},
            {"entry": "QA.MES", "entry_sha256": hashlib.sha256(callee).hexdigest()}]
        resume_start = branch_size + len(dispatch)
        route["caller"] = {"entry": "CALLER.MES", "offset": branch_size, "end": resume_start,
            "command": 15, "source_binding": {"kind": "typed_record"},
            "record_sha256": hashlib.sha256(dispatch).hexdigest()}
        route["callee"] = {"entry": "QA.MES", "offset": 0}
        route["outcome"] = {"offset": 0, "end": 1, "op": "command_00", "status": "script_return"}
        route["caller_outcome"] = {"kind": "dispatch"}
        route["qualification"] = "unconditional_caller_continuation_observation"
        route["origin_offset"] = 0
        route["unconditional_dispatch"] = {"record_count": 1, "edge_count": 1,
            "return_candidate_offsets": [],
            "prefix_sha256": hashlib.sha256(caller_code[:resume_start]).hexdigest()}
        route["selection_cases"] = [{"case_id": "baseline", "writes": [], "caller_message_count": 0}]
        route["state_context"] = {"kind": "fresh"}
        route["choice_contracts"] = []
        resume_end = resume_start + len(handoff)
        route["resume"] = {"start": resume_start, "message_count": 0, "expected_state": [],
            "boundary_policy": "natural_handoff",
            "outcome": {"offset": resume_start, "end": resume_end, "target": "MACHI.MES",
                "op": "script_handoff_marker", "status": "script_handoff_boundary",
                "record_sha256": hashlib.sha256(handoff).hexdigest(),
                "source_binding": {"kind": "typed_record"}}}
        route["reentry"] = {"outcome": deepcopy(route["outcome"]), "message_count": 0, "expected_state": []}
        route["variants"] = [{"variant_id": "default", "writes": [], "selections": [],
            "expected_state": [], "expected_resume_state": [], "message_count": 0}]
        for key in ("guard", "guard_cases", "post_guard_expected"):
            route.pop(key, None)
        self.sign()

    def test_v9_unconditional_dispatch_is_bound_to_the_original_window(self):
        self.unconditional_continuation_profile()
        report = self.run_audit()
        self.assertEqual(report, self.run_audit())
        self.assertEqual(report["schema"], "kakyu_event_analysis_group_source_audit/v9")
        self.assertIn("no_completion_claim", report["qualification"])
        window = report["unconditional_dispatch_windows"][report["profile"]["routes"][0]["route_id"]]
        self.assertEqual(window["escaping_edges"], [])
        self.assertEqual(window["interior_dispatch_offsets"], [])
        self.assertEqual(window["opaque_overlaps"], [])
        self.assertEqual(window["record_count"], 1)

    def test_v9_rejects_a_window_whose_edge_skips_the_dispatch(self):
        self.unconditional_continuation_profile(escaping=True)
        with self.assertRaises(ValueError):
            self.run_audit()

    def test_v9_unguarded_declarations_fail_closed(self):
        self.unconditional_continuation_profile()
        original = deepcopy(self.profile)
        mutations = {
            "record_count": lambda r: r["unconditional_dispatch"].update(record_count=2),
            "record_count_zero": lambda r: r["unconditional_dispatch"].update(record_count=0),
            "record_count_bool": lambda r: r["unconditional_dispatch"].update(record_count=True),
            "edge_count": lambda r: r["unconditional_dispatch"].update(edge_count=0),
            "edge_count_negative": lambda r: r["unconditional_dispatch"].update(edge_count=-1),
            "returns": lambda r: r["unconditional_dispatch"].update(return_candidate_offsets=[0]),
            "prefix": lambda r: r["unconditional_dispatch"].update(prefix_sha256="0" * 64),
            "guard_present": lambda r: r.update(guard={"offset": 0, "end": 11, "false_target": 11}),
            "post_guard": lambda r: r.update(post_guard_expected=0),
            "variant_post_guard": lambda r: r["variants"][0].update(post_guard_expected=0),
            "guard_truth": lambda r: r["selection_cases"][0].update(expected=1),
            "guarded_qualification": lambda r: r.update(qualification="caller_continuation_observation"),
            "origin_inside_a_record": lambda r: r.update(origin_offset=1),
            "origin_past_dispatch": lambda r: r.update(origin_offset=r["caller"]["offset"] + 1),
            "no_selection_cases": lambda r: r.update(selection_cases=[]),
            "duplicate_selection_case": lambda r: r["selection_cases"].append(deepcopy(r["selection_cases"][0])),
        }
        for name, mutate in mutations.items():
            self.profile = deepcopy(original)
            mutate(self.profile["routes"][0])
            self.sign()
            with self.subTest(mutation=name), self.assertRaises((ValueError, KeyError)):
                self.run_audit()

    def test_v9_accepts_the_def_selection_resume_policy(self):
        self.unconditional_continuation_profile()
        route = self.profile["routes"][0]
        archive = self.arc.read_bytes()
        caller_size = self.entries[0][2]
        callee = archive[caller_size:]
        code = archive[4:caller_size]
        stop_at = route["resume"]["start"]
        selection = bytes([0x1D, 0x02, 0x28, 0xFF, 0x00])
        code = code[:stop_at] + selection
        caller = bytes(4) + code
        self.arc.write_bytes(caller + callee)
        self.entries = [("CALLER.MES", 0, len(caller)), ("QA.MES", len(caller), len(callee))]
        self.profile["archive_sha256"] = hashlib.sha256(caller + callee).hexdigest()
        self.profile["source_members"][0]["entry_sha256"] = hashlib.sha256(caller).hexdigest()
        route["resume"]["boundary_policy"] = "def_selection_boundary"
        route["resume"]["outcome"].update(offset=stop_at, end=stop_at + len(selection),
            op="script_transfer", status="def_selection_boundary", target="",
            record_sha256=hashlib.sha256(selection).hexdigest())
        self.sign()
        report = self.run_audit()
        self.assertEqual(report["schema"], "kakyu_event_analysis_group_source_audit/v9")
        route_report = report["profile"]["routes"][0]
        self.assertEqual(route_report["resume"]["boundary_policy"], "def_selection_boundary")
        self.assertEqual(route_report["resume"]["start"], route_report["caller"]["end"])

    def test_v9_post_guard_expected_remains_rejected(self):
        # 0.315.0 only widens the guarded continuation schemas (V5, V8). An
        # unguarded route (V9) has no local guard for a post-guard truth to
        # describe, and keeps failing closed on both route and variant, the
        # same as V7 (test_v9_unguarded_declarations_fail_closed already
        # covers this via the shared unconditional_dispatch mutation matrix;
        # this is the dedicated, single-purpose regression for this feature).
        self.unconditional_continuation_profile()
        original = deepcopy(self.profile)
        for owner in ("route", "variant"):
            self.profile = deepcopy(original)
            route = self.profile["routes"][0]
            (route if owner == "route" else route["variants"][0])["post_guard_expected"] = 0
            self.sign()
            with self.subTest(owner=owner), self.assertRaises(ValueError):
                self.run_audit()

    def name_insert_window_profile(self, *, real_handoff=False):
        """A v9 window whose sole interior record is command 0x0E: the real
        game's protagonist-name-insert bytes (mes_instruction_ir.py's exact
        shape: tag 0xFF unknown_tag, tag 0x02 expression_record with raw_hex
        "00f90000a000e0f1400be0ff") by default, or a real command-0x0E handoff
        record when real_handoff=True, for comparison.
        """
        name_insert = bytes.fromhex("0eff0200f90000a000e0f1400be0ff00")
        real_handoff_bytes = bytes([0x0E, 0x01]) + b"OTHER.MES" + bytes([0, 0])
        head = real_handoff_bytes if real_handoff else name_insert
        dispatch = bytes([0x0F, 0x01]) + b"QA.MES" + bytes([0, 0])
        resume_handoff = bytes([0x0E, 0x01]) + b"MACHI.MES" + bytes([0, 0])
        caller_code = head + dispatch + resume_handoff
        caller = bytes(4) + caller_code
        callee = bytes(4) + bytes([0])
        archive = caller + callee
        self.arc.write_bytes(archive)
        self.entries = [("CALLER.MES", 0, len(caller)), ("QA.MES", len(caller), len(callee))]
        self.profile["schema"] = V9_SCHEMA
        self.profile["archive_sha256"] = hashlib.sha256(archive).hexdigest()
        self.profile["source_members"] = [
            {"entry": "CALLER.MES", "entry_sha256": hashlib.sha256(caller).hexdigest()},
            {"entry": "QA.MES", "entry_sha256": hashlib.sha256(callee).hexdigest()}]
        route = self.profile["routes"][0]
        resume_start = len(head) + len(dispatch)
        route["caller"] = {"entry": "CALLER.MES", "offset": len(head), "end": resume_start,
            "command": 15, "source_binding": {"kind": "typed_record"},
            "record_sha256": hashlib.sha256(dispatch).hexdigest()}
        route["callee"] = {"entry": "QA.MES", "offset": 0}
        route["outcome"] = {"offset": 0, "end": 1, "op": "command_00", "status": "script_return"}
        route["caller_outcome"] = {"kind": "dispatch"}
        route["qualification"] = "unconditional_caller_continuation_observation"
        route["origin_offset"] = 0
        route["unconditional_dispatch"] = {"record_count": 1, "edge_count": 0,
            "return_candidate_offsets": [],
            "prefix_sha256": hashlib.sha256(caller_code[:resume_start]).hexdigest()}
        route["selection_cases"] = [{"case_id": "baseline", "writes": [], "caller_message_count": 0}]
        route["state_context"] = {"kind": "fresh"}
        route["choice_contracts"] = []
        resume_end = resume_start + len(resume_handoff)
        route["resume"] = {"start": resume_start, "message_count": 0, "expected_state": [],
            "boundary_policy": "natural_handoff",
            "outcome": {"offset": resume_start, "end": resume_end, "target": "MACHI.MES",
                "op": "script_handoff_marker", "status": "script_handoff_boundary",
                "record_sha256": hashlib.sha256(resume_handoff).hexdigest(),
                "source_binding": {"kind": "typed_record"}}}
        route["reentry"] = {"outcome": deepcopy(route["outcome"]), "message_count": 0, "expected_state": []}
        route["variants"] = [{"variant_id": "default", "writes": [], "selections": [],
            "expected_state": [], "expected_resume_state": [], "message_count": 0}]
        for key in ("guard", "guard_cases", "post_guard_expected"):
            route.pop(key, None)
        self.sign()

    def test_v9_window_accepts_a_name_insert_but_rejects_a_real_handoff(self):
        self.name_insert_window_profile()
        report = self.run_audit()
        self.assertTrue(report["ok"])
        window = report["unconditional_dispatch_windows"][report["profile"]["routes"][0]["route_id"]]
        self.assertEqual(window["interior_dispatch_offsets"], [])
        self.assertEqual(window["record_count"], 1)

        self.setUp()
        self.name_insert_window_profile(real_handoff=True)
        with self.assertRaisesRegex(ValueError, "skip, divert or hide"):
            self.run_audit()


class AuditCacheTests(unittest.TestCase):
    """TD-32 part 2b: a per-entry handoff cache shared across profiles.

    Reuses `EventAnalysisGroupTests`' fixture (the synthetic archive, its
    entries and the base profile) without inheriting its test methods.
    """

    setUp = EventAnalysisGroupTests.setUp
    sign = EventAnalysisGroupTests.sign
    run_audit = EventAnalysisGroupTests.run_audit

    def test_cached_audit_equals_uncached_audit(self):
        with patch("audit_event_analysis_group.read_entries", return_value=self.entries):
            uncached = audit(self.arc, self.profile)
            cached = audit(self.arc, self.profile, handoff_cache={}, archive_cache={})
        self.assertEqual(uncached, cached)

    def test_second_profile_over_the_same_entries_reuses_the_handoff_cache(self):
        second = deepcopy(self.profile)
        second["group_id"] = "synthetic-second"
        second["payload_sha256"] = fingerprint(second)
        handoff_cache: dict = {}
        archive_cache: dict = {}
        with patch("audit_event_analysis_group.read_entries", return_value=self.entries), \
                patch("audit_event_analysis_group.build_handoff", wraps=build_handoff) as mock_build:
            first = audit(self.arc, self.profile, handoff_cache=handoff_cache, archive_cache=archive_cache)
            calls_after_first = mock_build.call_count
            second_report = audit(self.arc, second, handoff_cache=handoff_cache, archive_cache=archive_cache)
        self.assertGreater(calls_after_first, 0)
        self.assertEqual(mock_build.call_count, calls_after_first)
        self.assertTrue(first["ok"])
        self.assertTrue(second_report["ok"])

    def test_second_archive_with_a_same_named_entry_does_not_share_the_handoff_cache(self):
        # TD-32 part 2c: the cache key is `(archive_sha, entry name)`, so a
        # second, unrelated archive whose entries happen to share the first
        # archive's names must not reuse its handoffs.
        second_arc = Path(self.temp.name) / "mes2.arc"
        condition = bytes([0xF3, 2, 0, 0, 0xEF, 0xFF])  # global_u8[2] == 0 (differs from setUp's index 1)
        start = 1 + len(condition) + 4
        dispatch = b"\x0f\x01QA.MES\0\0"
        end = start + len(dispatch)
        code = b"\x0b" + condition + struct.pack("<I", end) + dispatch + b"\0"
        caller, callee = b"\0" * 4 + code, b"\0" * 5
        second_arc.write_bytes(caller + callee)
        second_entries = [("CALLER.MES", 0, len(caller)), ("QA.MES", len(caller), len(callee))]
        self.assertNotEqual(hashlib.sha256(caller + callee).hexdigest(), hashlib.sha256(
            self.arc.read_bytes()).hexdigest())

        second_profile = {"schema": SCHEMA, "group_id": "synthetic-second-archive",
            "archive_sha256": hashlib.sha256(caller + callee).hexdigest(),
            "source_members": [{"entry": name, "entry_sha256": hashlib.sha256(payload).hexdigest()}
                for name, payload in [("CALLER.MES", caller), ("QA.MES", callee)]],
            "routes": [{"route_id": "qa", "caller": {"entry": "CALLER.MES", "offset": start, "end": end, "command": 15},
                "callee": {"entry": "QA.MES", "offset": 0},
                "guard": {"offset": 0, "end": start, "false_target": end, "prefix_sha256": hashlib.sha256(code[:end]).hexdigest()},
                "caller_outcome": {"kind": "dispatch"},
                "outcome": {"offset": 0, "end": 1, "op": "command_00", "status": "script_return"},
                "baseline": [], "expected_state": [], "variants": [{"variant_id": "default", "writes": []}],
                "guard_cases": [{"case_id": "yes", "writes": [], "expected": 1},
                    {"case_id": "no", "writes": [{"storage": "global_u8", "bank": 0, "index": 2, "value": 1}], "expected": 0}]}]}
        second_profile["payload_sha256"] = fingerprint(second_profile)

        handoff_cache: dict = {}
        archive_cache: dict = {}

        def fake_read_entries(path):
            return second_entries if path == second_arc else self.entries

        with patch("audit_event_analysis_group.read_entries", side_effect=fake_read_entries), \
                patch("audit_event_analysis_group.build_handoff", wraps=build_handoff) as mock_build:
            first = audit(self.arc, self.profile, handoff_cache=handoff_cache, archive_cache=archive_cache)
            calls_after_first = mock_build.call_count
            second_report = audit(second_arc, second_profile, handoff_cache=handoff_cache, archive_cache=archive_cache)
        self.assertGreater(calls_after_first, 0)
        self.assertGreater(mock_build.call_count, calls_after_first)
        self.assertEqual(mock_build.call_count, calls_after_first * 2)
        self.assertTrue(first["ok"])
        self.assertTrue(second_report["ok"])

    def test_profiles_cli_prints_one_line_per_profile_with_a_failure_for_an_unreadable_path(self):
        good = Path(self.temp.name) / "profile.json"
        good.write_text(json.dumps(self.profile), encoding="utf-8")
        missing = Path(self.temp.name) / "missing.json"
        argv = ["audit_event_analysis_group.py", str(self.arc.parent),
                "--profiles", str(good), str(missing)]
        with patch("audit_event_analysis_group.read_entries", return_value=self.entries), \
                patch.object(sys, "argv", argv), contextlib.redirect_stdout(io.StringIO()) as out:
            exit_code = main()
        lines = [json.loads(line) for line in out.getvalue().splitlines() if line.strip()]
        self.assertEqual(len(lines), 2)
        self.assertEqual(lines[0]["profile"], str(good))
        self.assertTrue(lines[0]["report"]["ok"])
        self.assertEqual(lines[1]["profile"], str(missing))
        self.assertFalse(lines[1]["report"]["ok"])
        self.assertIn("error", lines[1]["report"])
        self.assertEqual(exit_code, 1)


class EventAnalysisFlowGroupTests(unittest.TestCase):
    """v14's flow shape (EP-12, 2026-09-24): a caller guard, two nested calls
    (the second with a routine-40 answer, both with a `resume` hop back in
    the caller), a root handoff into a second script that hands to a third.
    Per the owner's ruling this part declares nothing real - every fixture
    here is synthetic."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.arc = Path(self.temp.name) / "mes.arc"
        self.build_flow()

    def outcome(self, entry, offset, end, op, status, target=""):
        out = {"offset": offset, "end": end, "op": op, "status": status,
               "source_binding": {"kind": "typed_record"},
               "record_sha256": hashlib.sha256(self.payloads[entry][4 + offset:4 + end]).hexdigest()}
        if target:
            out["target"] = target
        return out

    def entered_by_from(self, kind, record):
        return {"kind": kind, "offset": record["offset"], "end": record["end"], "op": record["op"],
                "record_sha256": record["record_sha256"], "source_binding": record["source_binding"]}

    def build_flow(self, option_count=1):
        # QB.MES: a trivial nested-call target - just returns.
        qb_code = b"\0"

        # QC.MES: one routine-40 choice (one option), then returns - the same
        # registration/selection byte shape EventAnalysisGroupTests.chained_profile
        # uses for its own owned choice, reused here for one option.
        # `option_count` 2 adds a second one-byte definition (id 1), so the
        # variant tests can answer an option other than the hop's own.
        marker = b"\x1f\0\0\0\0"
        definition = len(marker)
        body, target_offset = definition + 9, definition + 10
        qc_code = marker + b"\x10\x02\0\xff\0" + struct.pack("<I", target_offset) + b"\0"
        definitions = [{"source_offset": definition, "body_offset": body,
                        "target_offset": target_offset, "definition_id": 0, "body_size": 1,
                        "body_sha256": hashlib.sha256(b"\0").hexdigest()}]
        for extra_id in range(1, option_count):
            extra_definition = len(qc_code)
            extra_body, extra_target = extra_definition + 9, extra_definition + 10
            qc_code += bytes([0x10, 0x02, extra_id, 0xff, 0]) + struct.pack("<I", extra_target) + b"\0"
            definitions.append({"source_offset": extra_definition, "body_offset": extra_body,
                                "target_offset": extra_target, "definition_id": extra_id, "body_size": 1,
                                "body_sha256": hashlib.sha256(b"\0").hexdigest()})
        boundary = len(qc_code)
        self.boundary = boundary
        qc_code += b"\x1d\x02\x28\xff\0"
        qc_return_offset = len(qc_code)
        qc_code += b"\0"

        # QE.MES: a trivial root-handoff target - just returns; the flow's terminal.
        qe_code = b"\0"
        # QD.MES: hands off immediately to QE.MES.
        qd_handoff = b"\x0e\x01QE.MES\0\0"
        qd_code = qd_handoff

        origin_marker = b"\x1f\0\0\0\0"
        condition = bytes([0xF3, 1, 0, 0, 0xEF, 0xFF])  # global_u8[1] == 0
        guard_offset = len(origin_marker)
        guard_head = bytes([0x0B]) + condition
        guard_end = guard_offset + len(guard_head) + 4
        dispatch_b = b"\x0f\x01QB.MES\0\0"
        dispatch1_offset, dispatch1_end = guard_end, guard_end + len(dispatch_b)
        dispatch_c = b"\x0f\x01QC.MES\0\0"
        dispatch2_offset, dispatch2_end = dispatch1_end, dispatch1_end + len(dispatch_c)
        handoff_d = b"\x0e\x01QD.MES\0\0"
        handoff1_offset, handoff1_end = dispatch2_end, dispatch2_end + len(handoff_d)
        reject_offset = handoff1_end
        false_target = reject_offset
        caller_code = (origin_marker + guard_head + struct.pack("<I", false_target)
                       + dispatch_b + dispatch_c + handoff_d + b"\0")
        self.assertEqual(len(caller_code), reject_offset + 1)

        names = ["CALLER.MES", "QB.MES", "QC.MES", "QD.MES", "QE.MES"]
        codes = {"CALLER.MES": caller_code, "QB.MES": qb_code, "QC.MES": qc_code,
                 "QD.MES": qd_code, "QE.MES": qe_code}
        self.payloads = {name: b"\0" * 4 + code for name, code in codes.items()}
        archive = b"".join(self.payloads[name] for name in names)
        self.arc.write_bytes(archive)
        cursor, entries = 0, []
        for name in names:
            entries.append((name, cursor, len(self.payloads[name])))
            cursor += len(self.payloads[name])
        self.entries = entries

        hop1_outcome = self.outcome("CALLER.MES", dispatch1_offset, dispatch1_end, "script_dispatch",
                                    "script_dispatch_boundary", "QB.MES")
        hop2_outcome = self.outcome("QB.MES", 0, 1, "command_00", "script_return")
        hop3_outcome = self.outcome("CALLER.MES", dispatch2_offset, dispatch2_end, "script_dispatch",
                                    "script_dispatch_boundary", "QC.MES")
        hop4_outcome = self.outcome("QC.MES", qc_return_offset, qc_return_offset + 1, "command_00", "script_return")
        hop5_outcome = self.outcome("CALLER.MES", handoff1_offset, handoff1_end, "script_handoff_marker",
                                    "script_handoff_boundary", "QD.MES")
        hop6_outcome = self.outcome("QD.MES", 0, len(qd_handoff), "script_handoff_marker",
                                    "script_handoff_boundary", "QE.MES")
        hop7_outcome = self.outcome("QE.MES", 0, 1, "command_00", "script_return")

        self.hops = [
            {"hop_id": "h1", "entry": "CALLER.MES", "entered_by": {"kind": "origin"},
             "answers": [], "gates": [], "map_locations": [], "poll_supplies": [],
             "expected": {"message_count": 0, "outcome": hop1_outcome, "expected_state": []}},
            {"hop_id": "h2", "entry": "QB.MES", "entered_by": self.entered_by_from("nested_call", hop1_outcome),
             "answers": [], "gates": [{"storage": "global_u8", "bank": 0, "index": 5, "value": 0,
                                        "op": "equal", "basis": "baseline"}], "map_locations": [], "poll_supplies": [],
             "expected": {"message_count": 0, "outcome": hop2_outcome, "expected_state": []}},
            {"hop_id": "h3", "entry": "CALLER.MES", "entered_by": self.entered_by_from("resume", hop2_outcome),
             "answers": [], "gates": [], "map_locations": [], "poll_supplies": [],
             "expected": {"message_count": 0, "outcome": hop3_outcome, "expected_state": []}},
            {"hop_id": "h4", "entry": "QC.MES", "entered_by": self.entered_by_from("nested_call", hop3_outcome),
             "answers": [{"boundary_offset": boundary, "result_value": 1}],
             "gates": [{"storage": "global_u8", "bank": 0, "index": 6, "value": 1,
                        "op": "equal", "basis": "tool_seeded"}], "map_locations": [], "poll_supplies": [],
             "expected": {"message_count": 0, "outcome": hop4_outcome, "expected_state": []}},
            {"hop_id": "h5", "entry": "CALLER.MES", "entered_by": self.entered_by_from("resume", hop4_outcome),
             "answers": [], "gates": [{"storage": "global_u8", "bank": 0, "index": 6, "value": 1,
                                        "op": "equal", "basis": "written_by:h4"}], "map_locations": [], "poll_supplies": [],
             "expected": {"message_count": 0, "outcome": hop5_outcome, "expected_state": []}},
            {"hop_id": "h6", "entry": "QD.MES", "entered_by": self.entered_by_from("root_handoff", hop5_outcome),
             "answers": [], "gates": [], "map_locations": [], "poll_supplies": [],
             "expected": {"message_count": 0, "outcome": hop6_outcome, "expected_state": []}},
            {"hop_id": "h7", "entry": "QE.MES", "entered_by": self.entered_by_from("root_handoff", hop6_outcome),
             "answers": [], "gates": [], "map_locations": [], "poll_supplies": [],
             "expected": {"message_count": 0, "outcome": hop7_outcome,
                          "expected_state": [{"storage": "global_u8", "bank": 0, "index": 1, "value": 1}]}},
        ]
        contract = {"schema": "kakyu_mes_routine40_choice_contract/v3",
            "boundary_offset": boundary, "resume_offset": qc_return_offset, "definition_count": option_count,
            "result_values": list(range(1, option_count + 1)), "definitions": definitions,
            "source_identity": {"archive": "mes.arc", "entry": "QC.MES"},
            "bytecode_sha256": hashlib.sha256(qc_code).hexdigest(), "code_size": len(qc_code)}

        self.route_static = {
            "route_id": "flow",
            "origin": {"entry": "CALLER.MES", "offset": 0,
                "guard": {"offset": guard_offset, "end": guard_end, "false_target": false_target,
                    "prefix_sha256": hashlib.sha256(caller_code[0:dispatch1_end]).hexdigest(),
                    "record_sha256": hashlib.sha256(caller_code[guard_offset:guard_end]).hexdigest(),
                    "source_binding": {"kind": "typed_record"}},
                "guard_cases": [
                    {"case_id": "yes", "writes": [], "expected": 1},
                    {"case_id": "no", "writes": [{"storage": "global_u8", "bank": 0, "index": 1, "value": 1}],
                     "expected": 0}]},
            "baseline": [],
            "state_context": {"kind": "fresh"},
            "choice_contracts": [contract],
            "terminal": {"entry": "QE.MES", **hop7_outcome},
            "variants": [{"variant_id": "default", "writes": [], "expected_state": []}],
            "unresolved": ["QB.MES gate index 5's own natural origin is not established"],
        }
        self.profile = {"schema": V14_SCHEMA, "group_id": "synthetic_flow",
            "archive_sha256": hashlib.sha256(archive).hexdigest(),
            "source_members": [{"entry": name, "entry_sha256": hashlib.sha256(self.payloads[name]).hexdigest()}
                                for name in names],
            "routes": [{**self.route_static, "hops": deepcopy(self.hops)}]}
        self.sign()

    def sign(self):
        self.profile["payload_sha256"] = fingerprint(self.profile)

    def run_audit(self):
        with patch("audit_event_analysis_group.read_entries", return_value=self.entries):
            return audit(self.arc, self.profile)

    def test_true_flow_profile_is_accepted(self):
        report = self.run_audit()
        self.assertTrue(report["ok"])
        self.assertEqual(report["schema"], "kakyu_event_analysis_group_source_audit/v14")
        self.assertIn("no_completion_claim", report["qualification"])
        self.assertEqual(report, self.run_audit())
        self.assertEqual(report["payload_sha256"], fingerprint(report))

    def test_shifted_dispatch_is_rejected(self):
        route = self.profile["routes"][0]
        route["hops"][1]["entered_by"]["offset"] += 1
        self.sign()
        with self.assertRaises((ValueError, KeyError)):
            self.run_audit()

    def test_wrong_outcome_is_rejected(self):
        route = self.profile["routes"][0]
        route["hops"][0]["expected"]["outcome"]["status"] = "script_return"
        self.sign()
        with self.assertRaises(ValueError):
            self.run_audit()

    def test_hop_out_of_order_is_rejected(self):
        route = self.profile["routes"][0]
        route["hops"][1], route["hops"][2] = route["hops"][2], route["hops"][1]
        self.sign()
        with self.assertRaises(ValueError):
            self.run_audit()

    def test_unbuildable_answer_is_rejected(self):
        route = self.profile["routes"][0]
        route["hops"][3]["answers"][0]["result_value"] = 2
        self.sign()
        with self.assertRaisesRegex(ValueError, "outside its own choice contract"):
            self.run_audit()

    def test_answer_at_an_undeclared_boundary_is_rejected(self):
        route = self.profile["routes"][0]
        route["hops"][3]["answers"][0]["boundary_offset"] += 1
        self.sign()
        with self.assertRaisesRegex(ValueError, "undeclared or duplicate choice"):
            self.run_audit()

    def add_variant(self, **fields):
        self.profile["routes"][0]["variants"].append(
            {"variant_id": "second", "writes": [], "expected_state": [], **fields})
        self.sign()

    def test_variant_answer_and_message_count_override_is_accepted(self):
        # EP-12 (2026-10-04, additive to v14): a variant answers another option
        # of the hop's own question and plays its own message count there.
        self.build_flow(option_count=2)
        self.assertTrue(self.run_audit()["ok"])
        self.add_variant(answers=[{"hop_id": "h4", "boundary_offset": self.boundary, "result_value": 2}],
                         message_counts={"h4": 3})
        report = self.run_audit()
        self.assertTrue(report["ok"])
        self.assertEqual(report, self.run_audit())
        # Either field alone is also a complete override.
        for fields in ({"answers": [{"hop_id": "h4", "boundary_offset": self.boundary, "result_value": 2}]},
                       {"message_counts": {"h2": 1}}):
            with self.subTest(fields=sorted(fields)):
                self.build_flow(option_count=2)
                self.add_variant(**fields)
                self.assertTrue(self.run_audit()["ok"])

    def test_variant_answer_is_bound_to_the_choice_contracts(self):
        self.build_flow(option_count=2)
        boundary = self.boundary
        cases = {
            "outside the contract": ([{"hop_id": "h4", "boundary_offset": boundary, "result_value": 3}],
                                     "outside its own choice contract"),
            "undeclared boundary": ([{"hop_id": "h4", "boundary_offset": boundary + 1, "result_value": 2}],
                                    "undeclared or duplicate choice"),
            "hop that owns no contract there": ([{"hop_id": "h2", "boundary_offset": boundary, "result_value": 1}],
                                                "undeclared or duplicate choice"),
            "undeclared hop": ([{"hop_id": "h9", "boundary_offset": boundary, "result_value": 2}],
                               "undeclared hop"),
            "not an integer value": ([{"hop_id": "h4", "boundary_offset": boundary, "result_value": "2"}],
                                     "malformed"),
            "no hop id": ([{"boundary_offset": boundary, "result_value": 2}], "malformed"),
            "repeated": ([{"hop_id": "h4", "boundary_offset": boundary, "result_value": 2}] * 2,
                         "undeclared or duplicate choice"),
            "not a list": ({"h4": 2}, "answers must be a list"),
        }
        for label, (answers, pattern) in cases.items():
            with self.subTest(label):
                self.build_flow(option_count=2)
                self.add_variant(answers=deepcopy(answers))
                with self.assertRaisesRegex(ValueError, pattern):
                    self.run_audit()

    def test_variant_message_counts_name_declared_hops_and_nonnegative_integers(self):
        cases = {
            "undeclared hop": ({"h9": 1}, "undeclared hop"),
            "negative": ({"h4": -1}, "Message observation count is invalid"),
            "not an integer": ({"h4": 1.5}, "Message observation count is invalid"),
            "boolean": ({"h4": True}, "Message observation count is invalid"),
            "not an object": ([["h4", 1]], "message counts must be an object"),
        }
        for label, (counts, pattern) in cases.items():
            with self.subTest(label):
                self.build_flow(option_count=2)
                self.add_variant(message_counts=counts)
                with self.assertRaisesRegex(ValueError, pattern):
                    self.run_audit()

    def test_a_hop_segment_budget_is_bound_to_its_range(self):
        # EP-12 H (2026-10-04, additive to v14): an optional per-hop probe
        # budget, an integer above the default 512 and at most 4096.
        for budget in (513, 1024, 4096):
            with self.subTest(accepted=budget):
                self.build_flow()
                self.profile["routes"][0]["hops"][1]["segment_budget"] = budget
                self.sign()
                self.assertTrue(self.run_audit()["ok"])
        for budget in (512, 0, -1, 5000, 4097, "1024", 1024.0, True, None):
            with self.subTest(refused=budget):
                self.build_flow()
                self.profile["routes"][0]["hops"][1]["segment_budget"] = budget
                self.sign()
                with self.assertRaisesRegex(ValueError, "segment_budget must be an integer above 512"):
                    self.run_audit()

    def test_bad_gate_basis_is_rejected(self):
        route = self.profile["routes"][0]
        for basis in ("written_by:h9", "written_by:h5", "not_a_real_basis"):
            with self.subTest(basis=basis):
                self.profile = deepcopy(self.profile)
                route = self.profile["routes"][0]
                route["hops"][4]["gates"][0]["basis"] = basis
                self.sign()
                with self.assertRaisesRegex(ValueError, "gate basis names an unknown or later hop"):
                    self.run_audit()

    def test_wrong_write_is_rejected(self):
        route = self.profile["routes"][0]
        route["hops"][6]["expected"]["expected_state"].append(
            {"storage": "global_u8", "bank": 0, "index": 1, "value": 999})
        self.sign()
        with self.assertRaisesRegex(ValueError, "unsupported, duplicate or out of range"):
            self.run_audit()

    def test_duplicate_write_within_a_hop_is_rejected(self):
        route = self.profile["routes"][0]
        write = route["hops"][6]["expected"]["expected_state"][0]
        route["hops"][6]["expected"]["expected_state"].append(dict(write))
        self.sign()
        with self.assertRaisesRegex(ValueError, "unsupported, duplicate or out of range"):
            self.run_audit()

    def test_resume_after_a_root_handoff_is_rejected(self):
        route = self.profile["routes"][0]
        route["hops"][5]["entered_by"] = self.entered_by_from("resume", route["hops"][4]["expected"]["outcome"])
        self.sign()
        with self.assertRaisesRegex(ValueError, "resume immediately after a nested call"):
            self.run_audit()

    def test_resume_in_the_wrong_script_is_rejected(self):
        route = self.profile["routes"][0]
        # h3 resumes after h2 (QB.MES); its own entry must be h1's (CALLER.MES).
        route["hops"][2]["entry"] = "QB.MES"
        self.sign()
        with self.assertRaises((ValueError, KeyError)):
            self.run_audit()

    def test_terminal_must_equal_the_last_hop_outcome(self):
        route = self.profile["routes"][0]
        route["terminal"]["end"] += 1
        self.sign()
        with self.assertRaisesRegex(ValueError, "Flow terminal"):
            self.run_audit()

    def test_missing_guard_witness_is_rejected(self):
        route = self.profile["routes"][0]
        route["origin"]["guard_cases"].pop()
        self.sign()
        with self.assertRaisesRegex(ValueError, "acceptance and rejection witnesses"):
            self.run_audit()

    def test_state_context_mutations_are_rejected(self):
        # EP-12 part 3 (2026-09-24): state_context is additive to v14, audited
        # by the same _audit_context every other schema uses - a bad kind, a
        # malformed fingerprint, and a source member this synthetic archive
        # never declares (CALLER.MES/QB.MES/QC.MES/QD.MES/QE.MES only, no
        # START.MES) are each rejected.
        original = deepcopy(self.profile)
        for mutation in ("kind", "fingerprint_shape", "missing_member"):
            self.profile = deepcopy(original)
            route = self.profile["routes"][0]
            if mutation == "kind":
                route["state_context"] = {"kind": "invented"}
            elif mutation == "fingerprint_shape":
                route["state_context"] = {"kind": "original_calendar", "entry": "START.MES", "table_sha256": "not-a-fingerprint"}
            elif mutation == "missing_member":
                route["state_context"] = {"kind": "original_calendar", "entry": "START.MES", "table_sha256": "0" * 64}
            self.sign()
            with self.subTest(mutation=mutation), self.assertRaisesRegex(ValueError, "Calendar context|Unsupported runtime state context"):
                self.run_audit()

    def test_v14_is_not_a_v6_or_v13_schema(self):
        self.assertNotIn(V14_SCHEMA, (SCHEMA, V2_SCHEMA, V3_SCHEMA, V4_SCHEMA, V5_SCHEMA, V6_SCHEMA,
                                       V7_SCHEMA, V8_SCHEMA, V9_SCHEMA, V10_SCHEMA, V11_SCHEMA,
                                       V12_SCHEMA, V13_SCHEMA))

    def flow_spec(self):
        return {
            "group_id": "synthetic_flow_built", "route_id": "flow",
            "source_members": ["CALLER.MES", "QB.MES", "QC.MES", "QD.MES", "QE.MES"],
            "origin": {"entry": "CALLER.MES", "offset": 0,
                "guard_offset": self.route_static["origin"]["guard"]["offset"],
                "guard_end": self.route_static["origin"]["guard"]["end"],
                "false_target": self.route_static["origin"]["guard"]["false_target"]},
            "guard_cases": self.route_static["origin"]["guard_cases"],
            "baseline": [],
            "state_context": self.route_static["state_context"],
            "choice_contracts": self.route_static["choice_contracts"],
            "variants": self.route_static["variants"],
            "unresolved": self.route_static["unresolved"],
            "hops": [{
                "hop_id": hop["hop_id"], "entry": hop["entry"],
                "entered_by_kind": hop["entered_by"]["kind"],
                "outcome_offset": hop["expected"]["outcome"]["offset"],
                "outcome_status": hop["expected"]["outcome"]["status"],
                "outcome_target": hop["expected"]["outcome"].get("target", ""),
                "message_count": hop["expected"]["message_count"],
                "expected_state": hop["expected"]["expected_state"],
                "answers": hop["answers"], "gates": hop["gates"],
            } for hop in self.hops],
        }

    def test_builder_reproduces_an_audit_passing_profile(self):
        with patch("build_event_flow_profile.read_entries", return_value=self.entries):
            built = build_flow_profile(self.arc, self.flow_spec())
        with patch("audit_event_analysis_group.read_entries", return_value=self.entries):
            report = audit(self.arc, built)
        self.assertTrue(report["ok"])
        built_route = built["routes"][0]
        hand_route = self.profile["routes"][0]
        self.assertEqual(built_route["hops"], hand_route["hops"])
        self.assertEqual(built_route["origin"], hand_route["origin"])
        self.assertEqual(built_route["terminal"], hand_route["terminal"])
        # No hop spec names a segment budget: no built hop carries the key.
        self.assertTrue(all("segment_budget" not in hop for hop in built_route["hops"]))

    def test_builder_copies_a_hop_segment_budget_only_when_the_spec_names_one(self):
        # EP-12 H (2026-10-04): a hop spec's `segment_budget` reaches the hop
        # verbatim and the audit binds it; the other hops are unchanged.
        spec = self.flow_spec()
        spec["hops"][1]["segment_budget"] = 1024
        with patch("build_event_flow_profile.read_entries", return_value=self.entries):
            built = build_flow_profile(self.arc, spec)
        hops = built["routes"][0]["hops"]
        self.assertEqual(hops[1]["segment_budget"], 1024)
        self.assertTrue(all("segment_budget" not in hop for index, hop in enumerate(hops) if index != 1))
        with patch("audit_event_analysis_group.read_entries", return_value=self.entries):
            self.assertTrue(audit(self.arc, built)["ok"])


if __name__ == "__main__":
    unittest.main()
