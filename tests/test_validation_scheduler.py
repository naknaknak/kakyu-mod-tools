"""TD-33: the `--jobs N` scheduler in `run_headless_validation.py`.

These are pure-Python unit tests against fake `Check`s (a mocked
`subprocess.run`, never a real Godot/Python child) - ordering, weights,
`exclusive`, the gate's first-come-first-served rule (TD-65),
report-row completeness independent of completion order, a
failing check not stopping the others, a timeout, and per-worker
environment isolation. `tests/test_run_headless_validation.py` still owns
the `--jobs 1` byte-for-byte-unchanged behaviour and the registry/report
plumbing end to end.
"""
from __future__ import annotations

import json
import shutil
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "content_suite"))

import run_headless_validation as validation  # noqa: E402

sys.path.insert(0, str(ROOT / "tests"))
from test_run_headless_validation import (  # noqa: E402
    _SHARDED_FAMILIES, _numbered_members, _shard_member_names, _summary_output_for,
)


def _check(name: str, *, weight: int = 1, exclusive: bool = False, timeout: int = 30) -> validation.Check:
    return validation.Check(
        name, (sys.executable, "-c", "pass"), timeout, ("synthetic",), "local", name,
        weight=weight, exclusive=exclusive,
    )


class WorkerGateTests(unittest.TestCase):
    def test_disjoint_slots_for_two_concurrent_weight_one_checks(self) -> None:
        gate = validation._WorkerGate(2)
        first = gate.acquire(1, False)
        second = gate.acquire(1, False)
        self.assertEqual(1, len(first))
        self.assertEqual(1, len(second))
        self.assertEqual(set(), set(first) & set(second))
        gate.release(first, False)
        gate.release(second, False)

    def test_weight_is_capped_to_total_jobs(self) -> None:
        gate = validation._WorkerGate(2)
        slots = gate.acquire(4, False)
        self.assertEqual(2, len(slots))
        gate.release(slots, False)

    def test_exclusive_blocks_until_every_other_slot_is_free(self) -> None:
        gate = validation._WorkerGate(2)
        held = gate.acquire(1, False)
        acquired_exclusive = threading.Event()

        def take_exclusive() -> None:
            slots = gate.acquire(1, True)
            acquired_exclusive.set()
            gate.release(slots, True)

        thread = threading.Thread(target=take_exclusive)
        thread.start()
        self.assertFalse(acquired_exclusive.wait(timeout=0.2), "exclusive acquired while a slot was still held")
        gate.release(held, False)
        self.assertTrue(acquired_exclusive.wait(timeout=5), "exclusive never acquired once the machine was free")
        thread.join()

    def test_exclusive_takes_every_slot_so_nothing_else_can_acquire(self) -> None:
        gate = validation._WorkerGate(3)
        slots = gate.acquire(1, True)
        self.assertEqual(3, len(slots))
        acquired_other = threading.Event()

        def take_one() -> None:
            other = gate.acquire(1, False)
            acquired_other.set()
            gate.release(other, False)

        thread = threading.Thread(target=take_one)
        thread.start()
        self.assertFalse(acquired_other.wait(timeout=0.2), "another check acquired while the exclusive check was running")
        gate.release(slots, True)
        self.assertTrue(acquired_other.wait(timeout=5))
        thread.join()



class _CountingCondition(threading.Condition):
    """A `Condition` that counts every `wait()` entry (always made with the
    lock held). A blocked waiter that is woken re-evaluates its predicate and,
    still blocked, enters `wait()` once more, so a test that releases slots
    can wait until every waiter has done that - a deterministic settle point
    for "nobody was served", with no sleep."""

    def __init__(self) -> None:
        super().__init__()
        self.waits = 0

    def wait(self, timeout=None):  # type: ignore[override]
        self.waits += 1
        return super().wait(timeout)


def _wait_until(predicate, timeout: float = 5.0) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(0.001)
    return bool(predicate())


class _Waiter:
    """A thread that acquires `weight` slots from `gate`, records its name in
    `log`, and holds the slots until `finish()` (or releases at once with
    `hold=False`). `start()` returns once the thread is queued (blocked in
    `wait()`) or has acquired, so the arrival order of several waiters is the
    order the test starts them in."""

    def __init__(self, gate: validation._WorkerGate, log: list[str], name: str, weight: int = 1,
                 exclusive: bool = False, hold: bool = True) -> None:
        self.gate = gate
        self.log = log
        self.name = name
        self.weight = weight
        self.exclusive = exclusive
        self.hold = hold
        self.acquired = threading.Event()
        self.slots: tuple[int, ...] = ()
        self._finish = threading.Event()
        self.thread = threading.Thread(target=self._run, name=name, daemon=True)

    def _run(self) -> None:
        self.slots = self.gate.acquire(self.weight, self.exclusive)
        self.log.append(self.name)
        self.acquired.set()
        if self.hold:
            self._finish.wait()
        self.gate.release(self.slots, self.exclusive)

    def start(self) -> None:
        condition = self.gate._condition
        before = condition.waits
        self.thread.start()
        _wait_until(lambda: condition.waits > before or self.acquired.is_set())

    def finish(self) -> None:
        self._finish.set()
        self.thread.join(timeout=5)


class WorkerGateFifoTests(unittest.TestCase):
    """TD-65: the gate serves waiters strictly in arrival order, so a
    multi-slot waiter is never overtaken by a later one."""

    @staticmethod
    def _gate(jobs: int) -> validation._WorkerGate:
        gate = validation._WorkerGate(jobs)
        gate._condition = _CountingCondition()
        return gate

    @staticmethod
    def _release_and_settle(gate: validation._WorkerGate, slots, exclusive: bool, blocked: int) -> None:
        """Release `slots`, then wait until each of the `blocked` waiters that
        stayed blocked has woken, re-evaluated and gone back to waiting."""
        before = gate._condition.waits
        gate.release(slots, exclusive)
        if not _wait_until(lambda: gate._condition.waits >= before + blocked):
            raise AssertionError("the blocked waiters did not all re-evaluate after the release")

    def test_a_multi_slot_head_is_served_before_later_single_slot_waiters(self) -> None:
        gate = self._gate(4)
        log: list[str] = []
        held = [gate.acquire(1, False) for _ in range(4)]
        head = _Waiter(gate, log, "head", weight=4)
        later = [_Waiter(gate, log, f"later-{index}") for index in range(2)]
        for waiter in (head, *later):
            waiter.start()
        # Slots free one at a time: a single-slot waiter would fit each, but
        # it sits behind the head, which needs all four.
        for index in range(3):
            self._release_and_settle(gate, held[index], False, blocked=3)
            self.assertEqual([], log, f"a waiter was served after {index + 1} slot(s) freed")
        gate.release(held[3], False)
        self.assertTrue(head.acquired.wait(timeout=5), "the head waiter was never served")
        self.assertEqual(["head"], log)
        self.assertFalse(any(waiter.acquired.is_set() for waiter in later))
        head.finish()
        for waiter in later:
            self.assertTrue(waiter.acquired.wait(timeout=5), f"{waiter.name} never ran")
            waiter.finish()
        self.assertEqual("head", log[0])
        self.assertEqual({"later-0", "later-1"}, set(log[1:]))

    def test_a_single_slot_waiter_does_not_take_slots_idled_ahead_of_a_multi_slot_head(self) -> None:
        # The idling trade: two slots are free, the single-slot waiter needs
        # one, and it still waits because the weight-3 head ahead of it does
        # not fit yet.
        gate = self._gate(4)
        log: list[str] = []
        held = [gate.acquire(1, False) for _ in range(2)]
        head = _Waiter(gate, log, "head", weight=3)
        single = _Waiter(gate, log, "single")
        head.start()
        single.start()
        self.assertFalse(single.acquired.is_set(), "a single-slot waiter took a slot ahead of the head")
        self.assertEqual(2, len(gate._free_slots), "the free slots were not left idle")
        self.assertEqual([], log)
        # One more slot frees: the head takes three and the single-slot waiter
        # still has none to take.
        gate.release(held[0], False)
        self.assertTrue(head.acquired.wait(timeout=5))
        self.assertFalse(single.acquired.is_set())
        # The second holder ends: one slot is free, and the single-slot waiter
        # now runs beside the head.
        gate.release(held[1], False)
        self.assertTrue(single.acquired.wait(timeout=5), "the single-slot waiter never ran")
        self.assertEqual(["head", "single"], log)
        head.finish()
        single.finish()

    def test_an_exclusive_head_drains_the_machine_before_any_later_waiter_starts(self) -> None:
        gate = self._gate(3)
        log: list[str] = []
        held = gate.acquire(1, False)
        exclusive = _Waiter(gate, log, "exclusive", exclusive=True)
        later = _Waiter(gate, log, "later")
        exclusive.start()
        later.start()
        # Two slots are free and the later waiter needs one, yet it waits.
        self.assertFalse(later.acquired.is_set(), "a later waiter started while an exclusive head waited")
        self.assertEqual(2, len(gate._free_slots))
        gate.release(held, False)
        self.assertTrue(exclusive.acquired.wait(timeout=5), "the exclusive head never ran")
        self.assertEqual(3, len(exclusive.slots))
        self.assertFalse(later.acquired.is_set(), "a later waiter started beside the exclusive check")
        exclusive.finish()
        self.assertTrue(later.acquired.wait(timeout=5), "the later waiter never ran after the exclusive check")
        later.finish()
        self.assertEqual(["exclusive", "later"], log)

    def test_waiters_are_served_in_arrival_order(self) -> None:
        # With 3 slots no two of these weights fit together, so each waiter
        # runs alone and the order they run in is the order they arrived in.
        gate = self._gate(3)
        log: list[str] = []
        held = gate.acquire(3, False)
        weights = [3, 2, 3, 2, 3, 2]
        waiters = [_Waiter(gate, log, f"w{index}", weight=weight) for index, weight in enumerate(weights)]
        for waiter in waiters:
            waiter.start()
        self.assertEqual(len(weights), len(gate._waiters))
        gate.release(held, False)
        for index, waiter in enumerate(waiters):
            self.assertTrue(waiter.acquired.wait(timeout=5), f"{waiter.name} never ran")
            self.assertEqual([w.name for w in waiters[: index + 1]], log)
            waiter.finish()
        self.assertEqual(0, len(gate._waiters))

    def test_no_waiter_starves_under_a_stream_of_later_arrivals(self) -> None:
        # A weight-4 head at --jobs 4 with a long stream of single-slot
        # waiters behind it: the head runs first and every one of them runs.
        gate = self._gate(4)
        log: list[str] = []
        held = [gate.acquire(1, False) for _ in range(4)]
        head = _Waiter(gate, log, "head", weight=4)
        stream = [_Waiter(gate, log, f"single-{index}", hold=False) for index in range(24)]
        head.start()
        for waiter in stream:
            waiter.start()
        for index in range(3):
            self._release_and_settle(gate, held[index], False, blocked=1 + len(stream))
        self.assertEqual([], log)
        gate.release(held[3], False)
        self.assertTrue(head.acquired.wait(timeout=5), "the head waiter starved")
        head.finish()
        for waiter in stream:
            waiter.thread.join(timeout=5)
            self.assertTrue(waiter.acquired.is_set(), f"{waiter.name} starved")
        self.assertEqual("head", log[0])
        self.assertEqual(1 + len(stream), len(log))

    def test_a_mixed_load_never_oversubscribes_the_slots_and_every_waiter_runs(self) -> None:
        import random

        jobs = 4
        gate = validation._WorkerGate(jobs)
        generator = random.Random(65)
        specs = [(generator.choice((1, 1, 1, 2, 4)), generator.random() < 0.05) for _ in range(60)]
        lock = threading.Lock()
        in_use: set[int] = set()
        problems: list[str] = []
        finished: list[int] = []

        def work(index: int, weight: int, exclusive: bool) -> None:
            slots = gate.acquire(weight, exclusive)
            with lock:
                expected = jobs if exclusive else min(weight, jobs)
                if len(slots) != expected:
                    problems.append(f"{index}: got {len(slots)} slots, wanted {expected}")
                if in_use & set(slots):
                    problems.append(f"{index}: slot ids {sorted(in_use & set(slots))} already in use")
                in_use.update(slots)
                if exclusive and in_use != set(slots):
                    problems.append(f"{index}: exclusive ran beside another check")
            time.sleep(0.0005)
            with lock:
                in_use.difference_update(slots)
                finished.append(index)
            gate.release(slots, exclusive)

        threads = [
            threading.Thread(target=work, args=(index, weight, exclusive), daemon=True)
            for index, (weight, exclusive) in enumerate(specs)
        ]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join(timeout=30)
        self.assertEqual([], problems)
        self.assertEqual(list(range(len(specs))), sorted(finished), "a waiter never ran")
        self.assertEqual(0, len(gate._waiters))
        self.assertEqual(list(range(jobs)), sorted(gate._free_slots))

    def test_a_waiter_that_leaves_the_queue_by_an_exception_does_not_block_those_behind_it(self) -> None:
        gate = self._gate(2)
        log: list[str] = []
        held = [gate.acquire(1, False) for _ in range(2)]
        condition = gate._condition
        real_wait = condition.wait
        errors: list[BaseException] = []

        def wait_then_fail_for_the_interrupted_thread(timeout=None):
            result = real_wait(timeout)
            if threading.current_thread().name == "interrupted":
                raise RuntimeError("interrupted while waiting")
            return result

        def interrupted() -> None:
            try:
                gate.acquire(1, False)
            except RuntimeError as error:
                errors.append(error)

        with mock.patch.object(condition, "wait", side_effect=wait_then_fail_for_the_interrupted_thread):
            thread = threading.Thread(target=interrupted, name="interrupted", daemon=True)
            before = condition.waits
            thread.start()
            self.assertTrue(_wait_until(lambda: condition.waits > before))
            behind = _Waiter(gate, log, "behind")
            behind.start()
            self.assertEqual(2, len(gate._waiters))
            # A slot frees: the interrupted head wakes and raises instead of
            # taking it, and the waiter behind it must then be served.
            gate.release(held[0], False)
            self.assertTrue(behind.acquired.wait(timeout=5), "the waiter behind an abandoned ticket never ran")
            thread.join(timeout=5)
        self.assertEqual(1, len(errors))
        self.assertEqual(["behind"], log)
        behind.finish()
        gate.release(held[1], False)
        self.assertEqual(0, len(gate._waiters))
        self.assertEqual([0, 1], sorted(gate._free_slots))


class OrderChecksForRunTests(unittest.TestCase):
    def test_registry_order_is_kept_when_nothing_is_recorded(self) -> None:
        checks = [_check("a"), _check("b"), _check("c")]
        with tempfile.TemporaryDirectory() as directory:
            ordered = validation._order_checks_for_run(
                checks, cache_dir=Path(directory) / "cache", report_path=None,
            )
        self.assertEqual(["a", "b", "c"], [check.name for check in ordered])

    def test_longest_recorded_cache_duration_runs_first(self) -> None:
        checks = [_check("short"), _check("long"), _check("medium")]
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            for name, duration in (("short", 1.0), ("long", 100.0), ("medium", 10.0)):
                entry_dir = cache_dir / "fp"
                entry_dir.mkdir(parents=True, exist_ok=True)
                (entry_dir / f"{name}.json").write_text(json.dumps({
                    "name": name, "duration_seconds": duration, "recorded_at": "2026-09-23T00:00:00+00:00",
                }), encoding="utf-8")
            ordered = validation._order_checks_for_run(checks, cache_dir=cache_dir, report_path=None)
        self.assertEqual(["long", "medium", "short"], [check.name for check in ordered])

    def test_report_durations_are_preferred_over_the_cache_when_both_exist(self) -> None:
        checks = [_check("a"), _check("b")]
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            entry_dir = cache_dir / "fp"
            entry_dir.mkdir(parents=True, exist_ok=True)
            (entry_dir / "a.json").write_text(json.dumps({
                "name": "a", "duration_seconds": 999.0, "recorded_at": "2026-09-23T00:00:00+00:00",
            }), encoding="utf-8")
            report_path = Path(directory) / "report.json"
            payload = {"checks": [
                {"name": "a", "duration_seconds": 1.0},
                {"name": "b", "duration_seconds": 50.0},
            ]}
            report_path.write_text(json.dumps({"payload_json": json.dumps(payload)}), encoding="utf-8")
            ordered = validation._order_checks_for_run(checks, cache_dir=cache_dir, report_path=report_path)
        self.assertEqual(["b", "a"], [check.name for check in ordered])

    def test_a_cached_row_in_the_report_is_not_a_usable_duration(self) -> None:
        checks = [_check("a"), _check("b")]
        with tempfile.TemporaryDirectory() as directory:
            report_path = Path(directory) / "report.json"
            payload = {"checks": [
                {"name": "a", "duration_seconds": 0, "cached": True},
                {"name": "b", "duration_seconds": 5.0},
            ]}
            report_path.write_text(json.dumps({"payload_json": json.dumps(payload)}), encoding="utf-8")
            ordered = validation._order_checks_for_run(
                checks, cache_dir=Path(directory) / "cache", report_path=report_path,
            )
        self.assertEqual(["b", "a"], [check.name for check in ordered])

    def test_a_cached_report_row_falls_back_to_the_cache_duration_per_check(self) -> None:
        # TD-40: one non-cached row in a reused report used to discard the whole cache.
        checks = [_check("ran"), _check("cached_long"), _check("unknown")]
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            entry_dir = cache_dir / "fp"
            entry_dir.mkdir(parents=True, exist_ok=True)
            (entry_dir / "cached_long.json").write_text(json.dumps({
                "name": "cached_long", "duration_seconds": 900.0, "recorded_at": "2026-10-03T00:00:00+00:00",
            }), encoding="utf-8")
            report_path = Path(directory) / "report.json"
            payload = {"checks": [
                {"name": "ran", "duration_seconds": 5.0},
                {"name": "cached_long", "duration_seconds": 0, "cached": True},
            ]}
            report_path.write_text(json.dumps({"payload_json": json.dumps(payload)}), encoding="utf-8")
            ordered = validation._order_checks_for_run(checks, cache_dir=cache_dir, report_path=report_path)
        self.assertEqual(["cached_long", "ran", "unknown"], [check.name for check in ordered])

    def test_a_report_duration_wins_over_the_cache_per_check_and_the_cache_fills_the_rest(self) -> None:
        checks = [_check("a"), _check("b"), _check("c")]
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            entry_dir = cache_dir / "fp"
            entry_dir.mkdir(parents=True, exist_ok=True)
            for name, duration in (("a", 999.0), ("c", 40.0)):
                (entry_dir / ("%s.json" % name)).write_text(json.dumps({
                    "name": name, "duration_seconds": duration, "recorded_at": "2026-10-03T00:00:00+00:00",
                }), encoding="utf-8")
            report_path = Path(directory) / "report.json"
            payload = {"checks": [{"name": "a", "duration_seconds": 1.0}, {"name": "b", "duration_seconds": 10.0}]}
            report_path.write_text(json.dumps({"payload_json": json.dumps(payload)}), encoding="utf-8")
            ordered = validation._order_checks_for_run(checks, cache_dir=cache_dir, report_path=report_path)
        # a: report 1.0 (not the cache's 999), b: report 10.0, c: cache 40.0.
        self.assertEqual(["c", "b", "a"], [check.name for check in ordered])

    def test_a_process_check_is_ordered_by_the_sum_of_its_members_durations(self) -> None:
        # TD-42: the analysis-group process check has no row under its own
        # name; its members' rows (report first, else cache, per member) are
        # the only recorded durations, and without the sum it sorted last.
        members = (_check("m1"), _check("m2"), _check("m3"))
        process = validation.Check(
            "process", (sys.executable, "-c", "pass"), 30, ("synthetic",), "local", None,
            family="analysis_group", members=members,
        )
        checks = [_check("small"), _check("big"), process, _check("unknown")]
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            entry_dir = cache_dir / "fp"
            entry_dir.mkdir(parents=True, exist_ok=True)
            for name, duration in (("small", 5.0), ("big", 100.0), ("m1", 70.0), ("m2", 900.0)):
                (entry_dir / ("%s.json" % name)).write_text(json.dumps({
                    "name": name, "duration_seconds": duration, "recorded_at": "2026-10-03T00:00:00+00:00",
                }), encoding="utf-8")
            report_path = Path(directory) / "report.json"
            payload = {"checks": [
                {"name": "m2", "duration_seconds": 60.0},
                {"name": "m3", "duration_seconds": 0, "cached": True},
            ]}
            report_path.write_text(json.dumps({"payload_json": json.dumps(payload)}), encoding="utf-8")
            ordered = validation._order_checks_for_run(checks, cache_dir=cache_dir, report_path=report_path)
            # m1 70 (cache) + m2 60 (report, not the cache's 900) + m3 0 = 130 > big 100.
            self.assertEqual(["process", "big", "small", "unknown"], [check.name for check in ordered])
            without_members = validation._order_checks_for_run(
                [_check("small"), _check("big"), _check("process")],
                cache_dir=cache_dir, report_path=report_path,
            )
        # The same name with no members stays unknown (0): the sum is the only source.
        self.assertEqual(["big", "small", "process"], [check.name for check in without_members])

    def test_a_missing_or_corrupt_report_still_uses_the_cache(self) -> None:
        checks = [_check("a"), _check("b")]
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            entry_dir = cache_dir / "fp"
            entry_dir.mkdir(parents=True, exist_ok=True)
            (entry_dir / "b.json").write_text(json.dumps({
                "name": "b", "duration_seconds": 7.0, "recorded_at": "2026-10-03T00:00:00+00:00",
            }), encoding="utf-8")
            report_path = Path(directory) / "report.json"
            report_path.write_text("not json", encoding="utf-8")
            for path in (report_path, Path(directory) / "absent.json"):
                ordered = validation._order_checks_for_run(checks, cache_dir=cache_dir, report_path=path)
                self.assertEqual(["b", "a"], [check.name for check in ordered])

    def test_recorded_durations_take_the_report_first_then_the_cache_per_name(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            entry_dir = cache_dir / "fp"
            entry_dir.mkdir(parents=True, exist_ok=True)
            for name, duration in (("a", 999.0), ("c", 40.0), ("d", 7.0)):
                (entry_dir / ("%s.json" % name)).write_text(json.dumps({
                    "name": name, "duration_seconds": duration, "recorded_at": "2026-10-03T00:00:00+00:00",
                }), encoding="utf-8")
            report_path = Path(directory) / "report.json"
            payload = {"checks": [
                {"name": "a", "duration_seconds": 1.0}, {"name": "b", "duration_seconds": 10.0},
                {"name": "d", "duration_seconds": 0, "cached": True},
            ]}
            report_path.write_text(json.dumps({"payload_json": json.dumps(payload)}), encoding="utf-8")
            self.assertEqual(
                {"a": 1.0, "b": 10.0, "c": 40.0, "d": 7.0},
                validation._recorded_durations(cache_dir, report_path),
            )
            self.assertEqual({"a": 999.0, "c": 40.0, "d": 7.0}, validation._recorded_durations(cache_dir, None))
            self.assertEqual({}, validation._recorded_durations(Path(directory) / "absent", None))

    def test_passing_the_durations_gives_the_same_order_as_reading_the_sources(self) -> None:
        # TD-58: `main()` reads the durations once and hands them over; the order must not depend on which.
        members = (_check("m1"), _check("m2"), _check("m3"))
        process = validation.Check(
            "process", (sys.executable, "-c", "pass"), 30, ("synthetic",), "local", None,
            family="analysis_group", members=members,
        )
        checks = [_check("small"), _check("big"), process, _check("unknown")]
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            entry_dir = cache_dir / "fp"
            entry_dir.mkdir(parents=True, exist_ok=True)
            for name, duration in (("small", 5.0), ("big", 100.0), ("m1", 70.0), ("m2", 900.0)):
                (entry_dir / ("%s.json" % name)).write_text(json.dumps({
                    "name": name, "duration_seconds": duration, "recorded_at": "2026-10-03T00:00:00+00:00",
                }), encoding="utf-8")
            report_path = Path(directory) / "report.json"
            payload = {"checks": [
                {"name": "m2", "duration_seconds": 60.0}, {"name": "m3", "duration_seconds": 0, "cached": True},
            ]}
            report_path.write_text(json.dumps({"payload_json": json.dumps(payload)}), encoding="utf-8")
            from_sources = validation._order_checks_for_run(checks, cache_dir=cache_dir, report_path=report_path)
            durations = validation._recorded_durations(cache_dir, report_path)
            for jobs in (1, 6):
                from_durations = validation._order_checks_for_run(
                    checks, cache_dir=Path(directory) / "unread", report_path=None, durations=durations, jobs=jobs,
                )
                self.assertEqual([check.name for check in from_sources], [check.name for check in from_durations])
            self.assertEqual(["process", "big", "small", "unknown"], [check.name for check in from_sources])
            # Explicit durations replace the sources outright.
            replaced = validation._order_checks_for_run(
                checks, cache_dir=cache_dir, report_path=report_path, durations={"small": 1.0, "unknown": 9.0},
            )
        self.assertEqual(["unknown", "small", "big", "process"], [check.name for check in replaced])

    def test_shard_process_checks_are_ordered_by_their_member_sums(self) -> None:
        durations = {"member 0": 100.0, "member 1": 5.0, "member 2": 60.0, "member 3": 50.0, "other": 120.0}
        collapsed = validation.collapse_families(
            [_check("other"), *_numbered_members(4), _check("unknown")], _SHARDED_FAMILIES, jobs=2, durations=durations,
        )
        self.assertEqual(
            [("member 0", "member 1"), ("member 2", "member 3")],
            _shard_member_names([check for check in collapsed if check.members]),
        )
        with tempfile.TemporaryDirectory() as directory:
            ordered = validation._order_checks_for_run(
                collapsed, cache_dir=Path(directory) / "cache", report_path=None, durations=durations, jobs=2,
            )
        # Shard 2 (60 + 50 = 110 s) before shard 1 (100 + 5 = 105 s); `other` (120 s) ahead of both.
        self.assertEqual(
            ["other", "original event analysis groups [2/2]", "original event analysis groups [1/2]", "unknown"],
            [check.name for check in ordered],
        )

    def test_a_check_with_members_stays_at_weight_one_whatever_its_weight(self) -> None:
        members = (_check("m1"), _check("m2"))
        process = validation.Check(
            "process", (sys.executable, "-c", "pass"), 30, ("synthetic",), "local", None,
            family="analysis_group", members=members, weight=4,
        )
        durations = {"m1": 50.0, "m2": 40.0, "other": 120.0}
        with tempfile.TemporaryDirectory() as directory:
            ordered = validation._order_checks_for_run(
                [process, _check("other")], cache_dir=Path(directory) / "cache", report_path=None,
                durations=durations, jobs=6,
            )
        # 90 s member sum at weight 1 (not 360 s) sorts after `other` at 120 s.
        self.assertEqual(["other", "process"], [check.name for check in ordered])

    def test_a_shorter_weight_four_check_sorts_before_a_longer_weight_one_check(self) -> None:
        # TD-58 D9: a weight-4 check parks a worker thread until four slots are free, so it starts early.
        checks = [_check("single"), _check("wide", weight=4)]
        durations = {"single": 500.0, "wide": 300.0}
        with tempfile.TemporaryDirectory() as directory:
            ordered = validation._order_checks_for_run(
                checks, cache_dir=Path(directory) / "cache", report_path=None, durations=durations, jobs=6,
            )
        self.assertEqual(["wide", "single"], [check.name for check in ordered])  # 1,200 s of slots against 500 s

    def test_the_weight_is_capped_at_jobs(self) -> None:
        checks = [_check("single"), _check("wide", weight=4)]
        durations = {"single": 700.0, "wide": 300.0}
        expected = {1: ["single", "wide"], 2: ["single", "wide"], 3: ["wide", "single"], 4: ["wide", "single"], 6: ["wide", "single"]}
        with tempfile.TemporaryDirectory() as directory:
            for jobs, names in expected.items():
                with self.subTest(jobs=jobs):
                    ordered = validation._order_checks_for_run(
                        checks, cache_dir=Path(directory) / "cache", report_path=None, durations=durations, jobs=jobs,
                    )
                    # min(4, jobs) slots: 300 x 2 = 600 < 700 at --jobs 2, but 300 x 3 = 900 > 700 at --jobs 3.
                    self.assertEqual(names, [check.name for check in ordered])

    def test_exclusive_checks_sort_after_every_other_check_by_duration(self) -> None:
        # TD-64 D4: an exclusive check takes every slot and the gate serves
        # waiters in arrival order (TD-65), so ordered anywhere but last it
        # drains the machine at its turn and holds back every check behind
        # it. The long one is longer than every other
        # check and the short one shorter than all, so neither the raw
        # duration nor the duration times `jobs` would seat either last.
        durations = {"long-exclusive": 500.0, "short-exclusive": 1.0, "corpus": 10.0, "tiny": 2.0, "weighted": 4.0}
        for exclusive_extra in ({}, {"weight": 4}):
            with self.subTest(**exclusive_extra):
                checks = [
                    _check("short-exclusive", exclusive=True, **exclusive_extra),
                    _check("tiny"),
                    _check("long-exclusive", exclusive=True, **exclusive_extra),
                    _check("corpus"),
                    _check("weighted", weight=4),
                ]
                with tempfile.TemporaryDirectory() as directory:
                    ordered = validation._order_checks_for_run(
                        checks, cache_dir=Path(directory) / "cache", report_path=None, durations=durations, jobs=6,
                    )
                # Non-exclusive checks keep D9's key (4 s x 4 slots = 16 > 10 s), exclusive ones follow, longest first.
                self.assertEqual(
                    ["weighted", "corpus", "tiny", "long-exclusive", "short-exclusive"],
                    [check.name for check in ordered],
                )


def _process_check(name: str, member_names: tuple[str, ...]) -> validation.Check:
    """A process check (`members`, the analysis-group shard's shape), keyed by
    its member sum and holding one slot."""
    return validation.Check(
        name, (sys.executable, "-c", "pass"), 30, ("synthetic",), "local", None,
        family="analysis_group", members=tuple(_check(member) for member in member_names),
    )


def _tie_checks() -> tuple[list[validation.Check], dict[str, float]]:
    """TD-67: the checks and cache durations that made TD-56's batch idle
    three slots for 839 s. `transfer` (945.5 s, one slot) and `suite`
    (236.33 s, four slots, key 945.32) tie; the shards are process checks
    whose member sums are 1,240.1 and 1,239.7 s. The list is in an order
    unlike any expected one, so only the sort and the rule decide the result."""
    checks = [
        _check("playback"), _check("analyzer"), _check("transfer"), _check("suite", weight=4),
        _process_check("shard-b", ("b1", "b2")), _process_check("shard-a", ("a1", "a2")),
        _check("equiv", weight=4),
    ]
    durations = {
        "equiv": 608.0, "a1": 620.05, "a2": 620.05, "b1": 619.85, "b2": 619.85,
        "transfer": 945.5, "suite": 236.33, "analyzer": 937.2, "playback": 619.8,
    }
    return checks, durations


def _order(checks: list[validation.Check], durations: dict[str, float], jobs: int) -> list[str]:
    with tempfile.TemporaryDirectory() as directory:
        ordered = validation._order_checks_for_run(
            checks, cache_dir=Path(directory) / "cache", report_path=None, durations=durations, jobs=jobs,
        )
    return [check.name for check in ordered]


class WeightFourBackToBackOrderTests(unittest.TestCase):
    """TD-67 (fix 1): after the duration-times-slots sort, the multi-slot
    checks run back to back with a window of single-slot fillers, at every
    `--jobs`. The reference is `fix1_order` of the TD-67 model."""

    def test_the_tie_keeps_the_suite_ahead_of_the_transfer_corpus_at_every_jobs(self) -> None:
        # D9 alone puts `transfer` (945.5) before `suite` (945.32 at --jobs 6): the
        # suite then reaches the head with three of its four slots free.
        checks, durations = _tie_checks()
        expected = {
            6: ["equiv", "shard-a", "shard-b", "suite", "transfer", "analyzer", "playback"],
            5: ["equiv", "shard-a", "suite", "shard-b", "transfer", "analyzer", "playback"],
            4: ["equiv", "suite", "shard-a", "shard-b", "transfer", "analyzer", "playback"],
            3: ["equiv", "suite", "shard-a", "shard-b", "transfer", "analyzer", "playback"],
            2: ["shard-a", "shard-b", "equiv", "suite", "transfer", "analyzer", "playback"],
        }
        for jobs, names in expected.items():
            with self.subTest(jobs=jobs):
                self.assertEqual(names, _order(checks, durations, jobs))

    def test_the_batchs_own_keys_give_the_same_back_to_back_rule(self) -> None:
        # TD-56's own durations (equivalence 579.2, suite 246.3, analyzer 931.8, transfer
        # 839.3, playback 628.9 s): at --jobs 6 D9 is already right; at 5 and 4 it is
        # not (the suite would head the queue with too few slots free).
        checks, _ = _tie_checks()
        durations = {
            "equiv": 579.2, "a1": 620.05, "a2": 620.05, "b1": 619.85, "b2": 619.85,
            "transfer": 839.3, "suite": 246.3, "analyzer": 931.8, "playback": 628.9,
        }
        expected = {
            6: ["equiv", "shard-a", "shard-b", "suite", "analyzer", "transfer", "playback"],
            5: ["equiv", "shard-a", "suite", "shard-b", "analyzer", "transfer", "playback"],
            4: ["equiv", "suite", "shard-a", "shard-b", "analyzer", "transfer", "playback"],
            3: ["equiv", "suite", "shard-a", "shard-b", "analyzer", "transfer", "playback"],
            2: ["shard-a", "shard-b", "equiv", "suite", "analyzer", "transfer", "playback"],
        }
        for jobs, names in expected.items():
            with self.subTest(jobs=jobs):
                self.assertEqual(names, _order(checks, durations, jobs))

    def test_a_single_slot_check_ahead_of_the_first_multi_slot_check_shrinks_the_window(self) -> None:
        # `lead` (500 s) sorts ahead of the first weight-4 check, so i0 = 1 and the
        # window is 6 - 4 - 1 = 1 filler, not 2.
        checks = [
            _check("tail"), _check("s3"), _check("s2"), _check("s1"), _check("suite", weight=4),
            _check("equiv", weight=4), _check("lead"),
        ]
        durations = {"lead": 500.0, "equiv": 110.0, "s1": 430.0, "s2": 420.0, "s3": 410.0, "suite": 100.0, "tail": 300.0}
        # D9: lead 500, equiv 440, s1 430, s2 420, s3 410, suite 400, tail 300.
        self.assertEqual(["lead", "equiv", "s1", "suite", "s2", "s3", "tail"], _order(checks, durations, 6))

    def test_fewer_than_two_multi_slot_checks_leave_the_sorted_order(self) -> None:
        checks, durations = _tie_checks()
        # --jobs 1 caps every weight at one slot: nothing is multi-slot, and the order is D9's.
        self.assertEqual(
            ["shard-a", "shard-b", "transfer", "analyzer", "playback", "equiv", "suite"],
            _order(checks, durations, 1),
        )
        # One weight-4 check among single-slot ones: nothing to keep back to back.
        single_wide = [check for check in checks if check.name != "suite"]
        self.assertEqual(
            ["equiv", "shard-a", "shard-b", "transfer", "analyzer", "playback"],
            _order(single_wide, durations, 6),
        )

    def test_exclusive_checks_stay_last_and_never_join_the_window_or_the_multi_slot_run(self) -> None:
        # An exclusive weight-4 check is not a multi-slot check for this rule (it sorts last,
        # TD-64 D4) and the window stops at it.
        checks, durations = _tie_checks()
        checks = checks + [_check("exclusive-wide", weight=4, exclusive=True)]
        durations = {**durations, "exclusive-wide": 3000.0}
        for jobs, names in {
            6: ["equiv", "shard-a", "shard-b", "suite", "transfer", "analyzer", "playback", "exclusive-wide"],
            4: ["equiv", "suite", "shard-a", "shard-b", "transfer", "analyzer", "playback", "exclusive-wide"],
        }.items():
            with self.subTest(jobs=jobs):
                self.assertEqual(names, _order(checks, durations, jobs))
        # The window is cut short by an exclusive check behind it: equiv, solo, suite, then it.
        few = [_check("equiv", weight=4), _check("suite", weight=4), _check("solo"), _check("exclusive-wide", weight=4, exclusive=True)]
        self.assertEqual(
            ["equiv", "solo", "suite", "exclusive-wide"],
            _order(few, {"equiv": 300.0, "suite": 100.0, "solo": 50.0, "exclusive-wide": 9.0}, 6),
        )

    def test_the_order_is_a_permutation_of_the_checks(self) -> None:
        checks, durations = _tie_checks()
        for jobs in range(1, 8):
            with self.subTest(jobs=jobs):
                self.assertEqual(sorted(check.name for check in checks), sorted(_order(checks, durations, jobs)))


class OrderedGateIdlenessTests(unittest.TestCase):
    """TD-67, at the gate: the order `_order_checks_for_run()` returns, fed to a
    strict-FIFO `_WorkerGate` the way the worker threads feed it, leaves no slot
    idle when a single-slot check is keyed between two weight-4 checks."""

    def test_a_single_slot_check_keyed_between_two_weight_four_checks_does_not_idle_slots(self) -> None:
        checks, durations = _tie_checks()
        with tempfile.TemporaryDirectory() as directory:
            ordered = validation._order_checks_for_run(
                checks, cache_dir=Path(directory) / "cache", report_path=None, durations=durations, jobs=6,
            )
        gate = validation._WorkerGate(6)
        gate._condition = _CountingCondition()
        log: list[str] = []
        waiters = [
            _Waiter(gate, log, check.name, weight=max(1, min(check.weight, 6)), exclusive=check.exclusive)
            for check in ordered
        ]
        try:
            for waiter in waiters:
                waiter.start()
            # The first three fill the six slots: the equivalence (4) and the two shards (1 each).
            self.assertEqual([], gate._free_slots, "the first three checks did not take every slot")
            self.assertEqual(len(waiters) - 3, len(gate._waiters))
            # The equivalence ends and frees its four slots. The head of the queue must be
            # the one check that needs exactly those four.
            waiters[0].finish()
            self.assertTrue(waiters[3].acquired.wait(timeout=5), "the fourth waiter was never served")
            self.assertEqual(
                [], gate._free_slots,
                "slots stayed idle after the equivalence ended: the fourth check in the returned order, %r, took %d slot(s)"
                % (waiters[3].name, len(waiters[3].slots)),
            )
            self.assertFalse(waiters[4].acquired.is_set(), "the fifth waiter started beside the fourth")
            self.assertEqual("suite", waiters[3].name)
        finally:
            for waiter in waiters:
                waiter._finish.set()
            for waiter in waiters:
                waiter.thread.join(timeout=5)


class RunChecksScheduledTests(unittest.TestCase):
    def _run(self, checks, *, jobs: int, fake_run):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            (project / "analysis").mkdir()
            with mock.patch.object(validation.subprocess, "run", side_effect=fake_run), \
                 mock.patch("builtins.print"):
                results, repo_worker_root, external_worker_root = validation.run_checks_scheduled(
                    checks, project, jobs=jobs, cache_dir=project / "cache", report_path=None,
                    run_id="11111111-1111-1111-1111-111111111111",
                )
        shutil.rmtree(external_worker_root, ignore_errors=True)
        return results, repo_worker_root, external_worker_root

    def test_every_check_produces_a_result_regardless_of_completion_order(self) -> None:
        # "fast" is ordered after "slow" by weight/registry order but
        # finishes first; every row must still be present in the result.
        order = []
        lock = threading.Lock()

        def fake_run(command, **kwargs):
            name = command[-1]
            if name == "slow":
                time.sleep(0.2)
            with lock:
                order.append(name)
            return mock.Mock(stdout="", returncode=0)

        checks = [
            validation.Check("slow", (sys.executable, "-c", "pass", "slow"), 30, ("synthetic",), "local", "slow"),
            validation.Check("fast", (sys.executable, "-c", "pass", "fast"), 30, ("synthetic",), "local", "fast"),
        ]
        results, _repo_worker_root, _external_worker_root = self._run(checks, jobs=2, fake_run=fake_run)
        self.assertEqual({"slow", "fast"}, {row["name"] for row in results})
        self.assertTrue(all(row["status"] == "passed" for row in results))
        # Confirms real concurrency happened: "fast" (no sleep) completed
        # before "slow" (0.2s sleep) even though both started together.
        self.assertEqual(["fast", "slow"], order)

    def test_a_failing_check_does_not_stop_the_others(self) -> None:
        def fake_run(command, **kwargs):
            name = command[-1]
            return mock.Mock(stdout="", returncode=1 if name == "failing" else 0)

        checks = [
            validation.Check("failing", (sys.executable, "-c", "pass", "failing"), 30, ("synthetic",), "local", "failing"),
            validation.Check("ok-one", (sys.executable, "-c", "pass", "ok-one"), 30, ("synthetic",), "local", "ok-one"),
            validation.Check("ok-two", (sys.executable, "-c", "pass", "ok-two"), 30, ("synthetic",), "local", "ok-two"),
        ]
        results, _repo_worker_root, _external_worker_root = self._run(checks, jobs=3, fake_run=fake_run)
        by_name = {row["name"]: row for row in results}
        self.assertEqual("failed", by_name["failing"]["status"])
        self.assertEqual("passed", by_name["ok-one"]["status"])
        self.assertEqual("passed", by_name["ok-two"]["status"])

    def test_a_timeout_is_reported_and_does_not_stop_the_others(self) -> None:
        import subprocess as subprocess_module

        def fake_run(command, **kwargs):
            name = command[-1]
            if name == "hangs":
                raise subprocess_module.TimeoutExpired(cmd=command, timeout=kwargs.get("timeout", 1))
            return mock.Mock(stdout="", returncode=0)

        checks = [
            validation.Check("hangs", (sys.executable, "-c", "pass", "hangs"), 1, ("synthetic",), "local", "hangs"),
            validation.Check("fine", (sys.executable, "-c", "pass", "fine"), 30, ("synthetic",), "local", "fine"),
        ]
        results, _repo_worker_root, _external_worker_root = self._run(checks, jobs=2, fake_run=fake_run)
        by_name = {row["name"]: row for row in results}
        self.assertEqual("timeout", by_name["hangs"]["status"])
        self.assertEqual("passed", by_name["fine"]["status"])

    def test_exclusive_check_never_overlaps_another_check(self) -> None:
        # Plain checks are free to overlap each other (jobs=4 permits it);
        # the only thing under test is that none of them ever overlaps the
        # exclusive one specifically.
        exclusive_active = threading.Event()
        plain_active = 0
        lock = threading.Lock()
        overlap_seen = threading.Event()

        def fake_run(command, **kwargs):
            nonlocal plain_active
            name = command[-1]
            if name == "exclusive-one":
                exclusive_active.set()
                with lock:
                    if plain_active > 0:
                        overlap_seen.set()
                time.sleep(0.15)
                exclusive_active.clear()
            else:
                with lock:
                    plain_active += 1
                if exclusive_active.is_set():
                    overlap_seen.set()
                time.sleep(0.05)
                with lock:
                    plain_active -= 1
            return mock.Mock(stdout="", returncode=0)

        checks = [
            validation.Check("exclusive-one", (sys.executable, "-c", "pass", "exclusive-one"), 30, ("synthetic",),
                              "local", "exclusive-one", exclusive=True),
            validation.Check("plain-a", (sys.executable, "-c", "pass", "plain-a"), 30, ("synthetic",), "local", "plain-a"),
            validation.Check("plain-b", (sys.executable, "-c", "pass", "plain-b"), 30, ("synthetic",), "local", "plain-b"),
            validation.Check("plain-c", (sys.executable, "-c", "pass", "plain-c"), 30, ("synthetic",), "local", "plain-c"),
        ]
        results, _repo_worker_root, _external_worker_root = self._run(checks, jobs=4, fake_run=fake_run)
        self.assertEqual(4, len(results))
        self.assertFalse(overlap_seen.is_set(), "a plain check overlapped the exclusive check")

    def test_heavy_weight_check_monopolizes_the_configured_jobs(self) -> None:
        # weight=2 with jobs=2 claims every slot, exactly like `exclusive`,
        # even though it is not marked exclusive: nothing else's fake_run
        # body may run while "heavy"'s own body is running. The two
        # weight-1 checks may still legitimately overlap *each other*.
        heavy_active = threading.Event()
        overlap_with_heavy = threading.Event()
        lock = threading.Lock()
        light_active = 0

        def fake_run(command, **kwargs):
            nonlocal light_active
            name = command[-1]
            if name == "heavy":
                heavy_active.set()
                with lock:
                    if light_active > 0:
                        overlap_with_heavy.set()
                time.sleep(0.15)
                heavy_active.clear()
            else:
                with lock:
                    light_active += 1
                if heavy_active.is_set():
                    overlap_with_heavy.set()
                time.sleep(0.05)
                with lock:
                    light_active -= 1
            return mock.Mock(stdout="", returncode=0)

        heavy = validation.Check(
            "heavy", (sys.executable, "-c", "pass", "heavy"), 30, ("synthetic",), "local", "heavy", weight=2,
        )
        light_a = validation.Check(
            "light-a", (sys.executable, "-c", "pass", "light-a"), 30, ("synthetic",), "local", "light-a",
        )
        light_b = validation.Check(
            "light-b", (sys.executable, "-c", "pass", "light-b"), 30, ("synthetic",), "local", "light-b",
        )
        results, _repo_worker_root, _external_worker_root = self._run([heavy, light_a, light_b], jobs=2, fake_run=fake_run)
        self.assertEqual(3, len(results))
        self.assertFalse(overlap_with_heavy.is_set(), "a weight-1 check overlapped the weight-2 check")

    def test_each_concurrently_running_check_gets_its_own_worker_environment(self) -> None:
        seen_appdata: set[str] = set()
        barrier = threading.Barrier(2, timeout=5)

        def fake_run(command, **kwargs):
            env = kwargs.get("env") or {}
            seen_appdata.add(env.get("APPDATA"))
            barrier.wait()
            return mock.Mock(stdout="", returncode=0)

        checks = [_check("worker-a"), _check("worker-b")]
        results, repo_worker_root, _external_worker_root = self._run(checks, jobs=2, fake_run=fake_run)
        self.assertEqual(2, len(results))
        self.assertEqual(2, len(seen_appdata))
        for appdata in seen_appdata:
            self.assertTrue(Path(appdata).is_relative_to(repo_worker_root))

    def test_a_worker_env_leaves_the_rest_of_the_environment_untouched(self) -> None:
        captured_env = {}

        def fake_run(command, **kwargs):
            captured_env.update(kwargs.get("env") or {})
            return mock.Mock(stdout="", returncode=0)

        with mock.patch.dict("os.environ", {"KAKYU_TD33_PROBE": "kept"}):
            self._run([_check("solo")], jobs=1 + 1, fake_run=fake_run)
        self.assertEqual("kept", captured_env.get("KAKYU_TD33_PROBE"))

    def test_a_python_kind_check_gets_temp_outside_the_tracked_project(self) -> None:
        # TD-33 follow-up: a Python child's TEMP/TMP must never resolve
        # inside the project - `tools/collect_mes_runtime_trace.py`'s
        # `ensure_safe_output()` (and its test) reasonably assumes
        # `tempfile.gettempdir()` is never inside the tracked project, and a
        # project-rooted TEMP broke exactly that check under `--jobs 4`
        # before this fix.
        captured_env = {}

        def fake_run(command, **kwargs):
            captured_env.update(kwargs.get("env") or {})
            return mock.Mock(stdout="", returncode=0)

        python_check = validation.Check(
            "python-ish", (sys.executable, "-c", "pass"), 30, ("synthetic",), "local", "python-ish",
            kind="python",
        )
        results, repo_worker_root, external_worker_root = self._run([python_check], jobs=1 + 1, fake_run=fake_run)
        self.assertEqual(1, len(results))
        self.assertNotEqual(repo_worker_root, external_worker_root)
        temp_path = Path(captured_env["TEMP"])
        self.assertEqual(captured_env["TEMP"], captured_env["TMP"])
        self.assertTrue(temp_path.is_relative_to(external_worker_root))
        self.assertFalse(temp_path.is_relative_to(repo_worker_root))
        with self.assertRaises(ValueError):
            temp_path.relative_to(repo_worker_root.parents[2])  # nowhere under the fake project root either


class SchedulerExceptionHandlingTests(unittest.TestCase):
    """Coordinator review of TD-33: a worker-thread exception - `_worker_env()`'s
    own `mkdir`, or any other unexpected failure `run_check()`/`_launch()`'s
    guarding does not already turn into a `timeout`/`error` result - must
    never silently drop a check from the report (the fail-open regression
    this closes: the thread died, no row was produced, and `main()`'s row
    assembly simply omitted the check, so a run missing one check's row
    could still report green).
    """

    def test_an_exception_inside_one_check_yields_an_error_row_prints_its_block_and_releases_slots(self) -> None:
        def fake_run_check(check, project, env=None):
            if check.name == "boom":
                raise RuntimeError("kaboom")
            return {"name": check.name, "status": "passed", "return_code": 0, "duration_seconds": 0.01}

        checks = [_check("boom"), _check("ok-a"), _check("ok-b")]
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            (project / "analysis").mkdir()
            with mock.patch.object(validation, "run_check", side_effect=fake_run_check), \
                 mock.patch("builtins.print") as fake_print:
                # jobs=1: exactly one worker slot. If `_run_one_scheduled()`
                # failed to release it after "boom" raised, "ok-a"/"ok-b"
                # could never acquire it - this call would then return with
                # fewer than 3 results (the pending queue only advances once
                # a slot frees up), which the assertions below would catch,
                # rather than the whole test suite hanging.
                results, _repo_worker_root, external_worker_root = validation.run_checks_scheduled(
                    checks, project, jobs=1, cache_dir=project / "cache", report_path=None,
                    run_id="33333333-3333-3333-3333-333333333333",
                )
        shutil.rmtree(external_worker_root, ignore_errors=True)

        by_name = {row["name"]: row for row in results}
        self.assertEqual(3, len(results))
        self.assertEqual("error", by_name["boom"]["status"])
        self.assertIsNone(by_name["boom"]["return_code"])
        self.assertIn("kaboom", by_name["boom"]["output_tail"])
        self.assertIn("RuntimeError", by_name["boom"]["output_tail"])
        # "ok-a"/"ok-b" only got to run at all because the single slot
        # "boom" held was released - the direct proof this test is for.
        self.assertEqual("passed", by_name["ok-a"]["status"])
        self.assertEqual("passed", by_name["ok-b"]["status"])

        printed = "".join(call.args[0] for call in fake_print.call_args_list if call.args)
        self.assertIn("kaboom", printed)
        self.assertIn("=== boom ===", printed)
        self.assertIn("SCHEDULER_EXCEPTION", printed)

    def test_an_exception_before_run_check_is_reached_is_also_caught(self) -> None:
        # `_worker_env()`'s own `mkdir` is the coordinator's named example of
        # a failure point outside `_launch()`'s guarding; simulated directly
        # so the test does not depend on actually breaking the filesystem.
        def fake_run_check(check, project, env=None):
            return {"name": check.name, "status": "passed", "return_code": 0, "duration_seconds": 0.01}

        checks = [_check("solo")]
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            (project / "analysis").mkdir()
            with mock.patch.object(validation, "run_check", side_effect=fake_run_check), \
                 mock.patch.object(validation, "_worker_env", side_effect=OSError("disk full")), \
                 mock.patch("builtins.print") as fake_print:
                results, _repo_worker_root, external_worker_root = validation.run_checks_scheduled(
                    checks, project, jobs=1, cache_dir=project / "cache", report_path=None,
                    run_id="44444444-4444-4444-4444-444444444444",
                )
        shutil.rmtree(external_worker_root, ignore_errors=True)
        self.assertEqual(1, len(results))
        self.assertEqual("error", results[0]["status"])
        self.assertIsNone(results[0]["return_code"])
        self.assertIn("disk full", results[0]["output_tail"])
        printed = "".join(call.args[0] for call in fake_print.call_args_list if call.args)
        self.assertIn("=== solo ===", printed)
        self.assertIn("disk full", printed)

    def test_a_process_family_check_exception_yields_one_error_row_per_member(self) -> None:
        members = (
            validation.Check(name="member a", command=(), timeout=1, groups=("original_corpus",), tier="full",
                              registry_name="member a", family="analysis_group", profile="a.json"),
            validation.Check(name="member b", command=(), timeout=1, groups=("original_corpus",), tier="full",
                              registry_name="member b", family="analysis_group", profile="b.json"),
        )
        process_check = validation.Check(
            name="original event analysis groups", command=(sys.executable, "-c", "pass"), timeout=30,
            groups=("original_corpus",), tier="full", registry_name=None, family="analysis_group", members=members,
        )

        def fake_run_check(check, project, env=None):
            raise RuntimeError("process launch exploded")

        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            (project / "analysis").mkdir()
            with mock.patch.object(validation, "run_check", side_effect=fake_run_check), \
                 mock.patch("builtins.print"):
                results, _repo_worker_root, external_worker_root = validation.run_checks_scheduled(
                    [process_check], project, jobs=1, cache_dir=project / "cache", report_path=None,
                    run_id="55555555-5555-5555-5555-555555555555",
                )
        shutil.rmtree(external_worker_root, ignore_errors=True)
        self.assertEqual(2, len(results))
        by_name = {row["name"]: row for row in results}
        for name in ("member a", "member b"):
            self.assertEqual("error", by_name[name]["status"])
            self.assertIsNone(by_name[name]["return_code"])
            self.assertIn("process launch exploded", by_name[name]["output_tail"])

    def test_a_timeout_in_one_shard_marks_only_that_shards_members_and_every_block_prints(self) -> None:
        durations = {"member 0": 8.0, "member 1": 5.0, "member 2": 4.0, "member 3": 3.0}
        shards = validation.collapse_families(_numbered_members(4), _SHARDED_FAMILIES, jobs=2, durations=durations)

        def fake_run(command, **kwargs):
            if any(argument.endswith("m0.json") for argument in command):
                raise validation.subprocess.TimeoutExpired(command, 30, output=b"partial\n")
            return validation.subprocess.CompletedProcess(command, 0, stdout=_summary_output_for(command))

        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            (project / "analysis").mkdir()
            with mock.patch.object(validation.subprocess, "run", side_effect=fake_run), \
                 mock.patch("builtins.print") as fake_print:
                results, _repo_worker_root, external_worker_root = validation.run_checks_scheduled(
                    shards, project, jobs=2, cache_dir=project / "cache", report_path=None,
                    run_id="66666666-6666-6666-6666-666666666666", durations=durations,
                )
        shutil.rmtree(external_worker_root, ignore_errors=True)
        self.assertEqual(
            {"member 0": "timeout", "member 3": "timeout", "member 1": "passed", "member 2": "passed"},
            {row["name"]: row["status"] for row in results},
        )
        printed = "".join(call.args[0] for call in fake_print.call_args_list if call.args)
        self.assertIn("=== original event analysis groups [1/2] ===\nshard plan: 1/2, 2 member(s), 11.000s known, 0 unknown", printed)
        self.assertIn("=== original event analysis groups [2/2] ===\nshard plan: 2/2, 2 member(s), 9.000s known, 0 unknown", printed)
        self.assertIn("process: original event analysis groups [1/2] timeout in ", printed)
        self.assertIn("process: original event analysis groups [2/2] completed in ", printed)

    def test_a_scheduler_exception_in_one_shard_yields_error_rows_for_that_shards_members_only(self) -> None:
        durations = {"member 0": 8.0, "member 1": 5.0, "member 2": 4.0, "member 3": 3.0}
        shards = validation.collapse_families(_numbered_members(4), _SHARDED_FAMILIES, jobs=2, durations=durations)

        def fake_run_check(check, project, env=None):
            if check.name.endswith("[1/2]"):
                raise RuntimeError("shard launch exploded")
            return [
                {"name": member.name, "status": "passed", "return_code": 0, "duration_seconds": 0.01}
                for member in check.members
            ]

        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            (project / "analysis").mkdir()
            with mock.patch.object(validation, "run_check", side_effect=fake_run_check), mock.patch("builtins.print"):
                results, _repo_worker_root, external_worker_root = validation.run_checks_scheduled(
                    shards, project, jobs=2, cache_dir=project / "cache", report_path=None,
                    run_id="77777777-7777-7777-7777-777777777777", durations=durations,
                )
        shutil.rmtree(external_worker_root, ignore_errors=True)
        by_name = {row["name"]: row for row in results}
        self.assertEqual(4, len(results))
        for name in ("member 0", "member 3"):
            self.assertEqual("error", by_name[name]["status"])
            self.assertIn("shard launch exploded", by_name[name]["output_tail"])
        for name in ("member 1", "member 2"):
            self.assertEqual("passed", by_name[name]["status"])


class AssembleResultsTests(unittest.TestCase):
    """`_assemble_results()` (extracted from `main()` in the same follow-up):
    the row assembly that used to be inline in `main()` and silently
    dropped a planned check with no result row (the sequential path is not
    known to hit this, but is protected the same way as a backstop)."""

    def test_a_hit_row_and_a_run_row_keep_the_checks_own_planned_order(self) -> None:
        checks = [_check("a"), _check("b"), _check("c")]
        hit_rows = [{
            "name": "b", "status": "passed", "return_code": 0, "duration_seconds": 0.0,
            "cached": True, "cached_at": "x", "cached_run_id": "y",
        }]
        run_results = [
            {"name": "a", "status": "passed", "return_code": 0, "duration_seconds": 1.0},
            {"name": "c", "status": "passed", "return_code": 0, "duration_seconds": 2.0},
        ]
        results = validation._assemble_results(checks, hit_rows, run_results)
        self.assertEqual(["a", "b", "c"], [row["name"] for row in results])

    def test_a_planned_check_with_no_result_row_becomes_a_synthetic_error_row(self) -> None:
        checks = [_check("present"), _check("missing")]
        run_results = [{"name": "present", "status": "passed", "return_code": 0, "duration_seconds": 1.0}]
        results = validation._assemble_results(checks, [], run_results)
        by_name = {row["name"]: row for row in results}
        self.assertEqual(2, len(results))
        self.assertEqual("passed", by_name["present"]["status"])
        self.assertEqual("error", by_name["missing"]["status"])
        self.assertIsNone(by_name["missing"]["return_code"])
        self.assertEqual(validation.NO_RESULT_OUTPUT_TAIL, by_name["missing"]["output_tail"])


if __name__ == "__main__":
    unittest.main()
