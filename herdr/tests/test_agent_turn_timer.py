"""Turn timing tests use synthetic clocks and an isolated stub Herdr CLI."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("turn_timer", HERE / "agent-turn-timer.py")
timer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(timer)
PANE = "w1:p1"


def agent(status, session="session-1", elapsed=None):
    return {"pane_id": PANE, "terminal_id": "terminal-1", "agent": "pi",
            "agent_status": status, "agent_session": {"value": session},
            "tokens": {"elapsed": elapsed} if elapsed is not None else {}}


class TurnTransitionsTests(unittest.TestCase):
    def test_blocked_freezes_then_resumes_without_counting_wait(self):
        turn = timer.advance(None, agent("working"), 100)
        turn = timer.advance(turn, agent("blocked"), 220)
        self.assertEqual(turn["seconds"], 120)
        self.assertIsNone(turn["since"])
        self.assertEqual(timer.elapsed_label(turn, 2000), "2m")
        turn = timer.advance(turn, agent("working"), 2000)
        turn = timer.advance(turn, agent("done"), 2060)
        self.assertEqual(turn["seconds"], 180)
        self.assertEqual(timer.elapsed_label(turn, 9999), "3m")

    def test_completed_and_seen_idle_keep_duration_until_next_turn(self):
        turn = timer.advance(None, agent("working"), 100)
        turn = timer.advance(turn, agent("done"), 250)
        turn = timer.advance(turn, agent("idle"), 1000)
        self.assertEqual(timer.elapsed_label(turn, 2000), "2m")
        turn = timer.advance(turn, agent("working"), 2000)
        self.assertEqual(turn["seconds"], 0)
        self.assertEqual(turn["since"], 2000)
        self.assertEqual(timer.elapsed_label(turn, 2000), "<1m")

    def test_idle_completion_also_preserves_duration(self):
        turn = timer.advance(None, agent("working"), 10)
        turn = timer.advance(turn, agent("idle"), 75)
        self.assertEqual(timer.elapsed_label(turn, 2000), "1m")

    def test_uncertain_status_does_not_reset_an_inflight_turn(self):
        turn = timer.advance(None, agent("working"), 0)
        turn = timer.advance(turn, agent("unknown"), 90)
        turn = timer.advance(turn, agent("working"), 900)
        self.assertEqual(timer.elapsed_label(turn, 930), "2m")

    def test_completed_turn_does_not_resume_through_unknown_or_blocked(self):
        for between in ("unknown", "blocked"):
            with self.subTest(between=between):
                turn = timer.advance(None, agent("working"), 0)
                turn = timer.advance(turn, agent("done"), 120)
                turn = timer.advance(turn, agent(between), 150)
                turn = timer.advance(turn, agent("working"), 200)
                self.assertEqual(timer.elapsed_label(turn, 200), "<1m")

    def test_no_historical_duration_is_invented_for_stopped_agents(self):
        for status in ("done", "idle", "blocked", "unknown"):
            with self.subTest(status=status):
                self.assertIsNone(timer.advance(None, agent(status), 100))

    def test_new_occupant_does_not_inherit_previous_duration(self):
        turn = timer.advance(None, agent("working"), 100)
        turn = timer.advance(turn, agent("done"), 300)
        self.assertIsNone(timer.advance(turn, agent("idle", session="new-session"), 500))
        new = timer.advance(turn, agent("working", session="new-session"), 500)
        self.assertEqual(timer.elapsed_label(new, 500), "<1m")
        replacement = agent("working")
        replacement["terminal_id"] = "terminal-2"
        self.assertEqual(timer.advance(turn, replacement, 500)["seconds"], 0)

    def test_late_session_identity_does_not_reset_running_timer(self):
        turn = timer.advance(None, agent("working", session=None), 100)
        turn = timer.advance(turn, agent("working"), 230)
        self.assertEqual(timer.elapsed_label(turn, 230), "2m")
        self.assertEqual(turn["identity"]["session"], "session-1")

    def test_clock_rollback_never_produces_negative_duration(self):
        turn = timer.advance(None, agent("working"), 100)
        turn = timer.advance(turn, agent("blocked"), 90)
        self.assertEqual(turn["seconds"], 0)


class ReportingTests(unittest.TestCase):
    def test_migrates_current_start_and_forces_removal_of_old_ttl(self):
        original = {"starts": {PANE: 100}, "labels": {PANE: "2m"},
                    "profiles": {PANE: "S/h"}, "pane_sessions": {PANE: "keep-me"}}
        state, updates = timer.plan(original, [agent("done", elapsed="2m")], 250)
        self.assertEqual(state["turns"][PANE]["seconds"], 150)
        self.assertEqual(updates, {PANE: "2m"})
        self.assertEqual(state["starts"], {})
        self.assertEqual(state["pane_sessions"], original["pane_sessions"])
        self.assertEqual(original["starts"], {PANE: 100})

    def test_disappeared_agents_are_cleaned_up(self):
        state = {"turns": {PANE: timer.advance(None, agent("working"), 100)},
                 "labels": {PANE: "2m"}}
        state, updates = timer.plan(state, [], 250)
        self.assertEqual(state["turns"], {})
        self.assertEqual(state["labels"], {})
        self.assertEqual(updates, {PANE: None})

    def test_stale_token_on_replaced_idle_agent_is_cleared(self):
        old = timer.advance(None, agent("working"), 100)
        state, updates = timer.plan({"turns": {PANE: old}, "labels": {PANE: "2m"}},
                                   [agent("idle", session="new-session", elapsed="2m")], 250)
        self.assertNotIn(PANE, state["turns"])
        self.assertEqual(updates, {PANE: None})

    def test_reports_display_metadata_without_ttl_or_lifecycle_changes(self):
        with mock.patch.object(timer.subprocess, "run", return_value=subprocess.CompletedProcess("herdr", 0)) as run:
            self.assertTrue(timer.publish("herdr-test", PANE, "3m"))
        self.assertEqual(run.call_args.args[0],
                         ["herdr-test", "pane", "report-metadata", PANE, "--source", "user:elapsed-tracker",
                          "--token", "elapsed=3m"])

    def test_publish_timeout_is_retryable(self):
        with mock.patch.object(timer.subprocess, "run", side_effect=subprocess.TimeoutExpired("herdr", 1)):
            self.assertFalse(timer.publish("herdr", PANE, "3m"))

    def test_failed_report_preserves_stop_time_and_retries(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "state.json"
            path.write_text(json.dumps({"starts": {PANE: 100}, "profiles": {PANE: "S/h"},
                                        "sessions": {"keep": 1}, "pane_sessions": {"other": 2}}))
            with mock.patch.object(timer, "publish", return_value=False):
                timer.tick(path, [agent("done")], 250, "herdr")
            state = json.loads(path.read_text())
            self.assertEqual(state["turns"][PANE]["seconds"], 150)
            self.assertNotIn("reported", state["turns"][PANE])
            with mock.patch.object(timer, "publish", return_value=True) as publish:
                timer.tick(path, [agent("done")], 1000, "herdr")
            publish.assert_called_once_with("herdr", PANE, "2m")
            state = json.loads(path.read_text())
            self.assertEqual(state["labels"][PANE], "2m")
            self.assertEqual(state["profiles"][PANE], "S/h")
            self.assertEqual(state["sessions"], {"keep": 1})
            self.assertEqual(state["pane_sessions"], {"other": 2})
            with mock.patch.object(timer, "publish", return_value=True) as publish:
                timer.tick(path, [agent("idle", elapsed="2m")], 2000, "herdr")
                publish.assert_not_called()
            # Missing token (e.g. server metadata expired/restarted) is restored.
            with mock.patch.object(timer, "publish", return_value=True) as publish:
                timer.tick(path, [agent("idle")], 2100, "herdr")
                publish.assert_called_once_with("herdr", PANE, "2m")


@unittest.skipUnless(shutil.which("jq"), "jq not installed")
class ShellIntegrationTests(unittest.TestCase):
    def test_existing_tracker_retains_completion_then_resets_next_turn(self):
        with tempfile.TemporaryDirectory(prefix="timer-shell-", dir="/tmp") as tmp:
            root = Path(tmp)
            for filename in ("agent-elapsed-tracker.sh", "agent-turn-timer.py"):
                shutil.copy2(HERE / filename, root / filename)
            snapshot = root / "agents.json"
            snapshot.write_text(json.dumps({"result": {"agents": [agent("done", elapsed="2m")]}}))
            state = root / "agent-elapsed-state.json"
            state.write_text(json.dumps({"starts": {PANE: int(time.time()) - 150},
                                         "labels": {PANE: "2m"}, "profiles": {}, "sessions": {}}))
            fake = root / "herdr-stub"
            fake.write_text(f'''#!{sys.executable}
import json, os, sys
from pathlib import Path
root = Path(__file__).parent
if sys.argv[1:] == ["agent", "list"]:
    print((root / "agents.json").read_text())
elif sys.argv[1:3] == ["pane", "report-metadata"]:
    with (root / "reports.jsonl").open("a") as stream:
        stream.write(json.dumps(sys.argv[1:]) + "\\n")
else:
    sys.exit(2)
''')
            fake.chmod(0o755)
            env = dict(os.environ, HERDR_BIN_PATH=str(fake), HOME=str(root))
            subprocess.run(["sh", str(root / "agent-elapsed-tracker.sh")], env=env,
                           check=True, capture_output=True, timeout=10)
            stopped = json.loads(state.read_text())
            self.assertEqual(stopped["labels"][PANE], "2m")
            self.assertTrue(stopped["turns"][PANE]["finished"])
            reports = [json.loads(line) for line in (root / "reports.jsonl").read_text().splitlines()]
            self.assertIn("elapsed=2m", reports[0])
            self.assertNotIn("--ttl-ms", reports[0])
            self.assertNotIn("--clear-token", reports[0])
            snapshot.write_text(json.dumps({"result": {"agents": [agent("working", elapsed="2m")]}}))
            subprocess.run(["sh", str(root / "agent-elapsed-tracker.sh")], env=env,
                           check=True, capture_output=True, timeout=10)
            self.assertEqual(json.loads(state.read_text())["labels"][PANE], "<1m")


if __name__ == "__main__":
    unittest.main()
