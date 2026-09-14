"""Run with: python3 -B -m unittest discover -s herdr/tests -v."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import threading
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location(
    "agent_picker", Path(__file__).resolve().parents[1] / "agent-picker.py"
)
picker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(picker)


@contextlib.contextmanager
def fake_herdr(reply):
    """Exercise the actual socket framing without contacting a live session."""
    with tempfile.TemporaryDirectory(prefix="picker-test-", dir="/tmp") as tmp:
        path = str(Path(tmp) / "herdr.sock")
        requests = []
        errors = []
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
            server.bind(path)
            server.listen(1)
            server.settimeout(2)

            def serve():
                try:
                    connection, _ = server.accept()
                    with connection, connection.makefile("rb") as stream:
                        connection.settimeout(2)
                        requests.append(json.loads(stream.readline()))
                        connection.sendall(reply)
                except Exception as exc:
                    errors.append(exc)

            worker = threading.Thread(target=serve, daemon=True)
            worker.start()
            try:
                with mock.patch.dict(os.environ, {"HERDR_SOCKET_PATH": path}):
                    yield requests
            finally:
                worker.join(timeout=3)
                if worker.is_alive():
                    raise AssertionError("fake Herdr did not finish")
                if errors:
                    raise errors[0]


def response(**values):
    return (json.dumps({"id": "agent-picker:focus", **values}) + "\n").encode()


class FocusTests(unittest.TestCase):
    def test_uses_pane_focus_not_agent_focus_for_client_projection(self):
        reply = response(result={"type": "pane_info", "pane": {
            "pane_id": "w2:p3", "focused": True,
        }})
        with fake_herdr(reply) as requests:
            picker.focus_pane("w2:p3")
        self.assertEqual(requests, [{
            "id": "agent-picker:focus", "method": "pane.focus",
            "params": {"pane_id": "w2:p3"},
        }])

    def test_missing_socket_never_guesses_default_session(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(picker.PickerError, "HERDR_SOCKET_PATH"):
                picker.focus_pane("w2:p3")

    def test_closed_pane_error_is_not_swallowed(self):
        reply = response(error={"code": "pane_not_found", "message": "pane was closed"})
        with fake_herdr(reply):
            with self.assertRaisesRegex(picker.PickerError, "pane_not_found: pane was closed"):
                picker.focus_pane("w2:p3")

    def test_rejects_truncated_or_mismatched_response(self):
        replies = [
            b'{"id": "agent-picker:focus"}',
            response(id="wrong-request"),
            response(result={"pane": {"pane_id": "w1:p1", "focused": True}}),
            response(result={"pane": {"pane_id": "w2:p3", "focused": False}}),
        ]
        for reply in replies:
            with self.subTest(reply=reply), fake_herdr(reply):
                with self.assertRaises(picker.PickerError):
                    picker.focus_pane("w2:p3")


class StatusIconTests(unittest.TestCase):
    def test_symbol_glyphs_and_colors_match_herdr_sidebar(self):
        expected = {
            "working": "\x1b[33m◐\x1b[0m", "blocked": "\x1b[31m×\x1b[0m",
            "done": "\x1b[36m✓\x1b[0m", "idle": "\x1b[32m○\x1b[0m",
            "unknown": "\x1b[90m·\x1b[0m",
        }
        for status, icon in expected.items():
            with self.subTest(status=status):
                self.assertEqual(picker.status_icon(status, {}), icon)

    def test_done_uses_theme_teal_not_green(self):
        self.assertEqual(picker.status_icon("done", {"green": "#286983", "teal": "#56949f"}),
                         "\x1b[38;2;86;148;159m✓\x1b[0m")

    def test_dots_mode_matches_sidebar_configuration(self):
        for status in ("working", "blocked", "done"):
            with self.subTest(status=status):
                self.assertIn("●", picker.status_icon(status, {}, "dots"))
        self.assertIn("○", picker.status_icon("idle", {}, "dots"))
        self.assertIn("·", picker.status_icon("unknown", {}, "dots"))

    def test_other_states_are_not_presented_as_completed(self):
        for state in ("idle", "working", "blocked", "unknown"):
            with self.subTest(state=state):
                self.assertNotIn("✓", picker.status_icon(state, {}))
        self.assertIn("○", picker.status_icon("idle", {}))


class CurrentAgentTests(unittest.TestCase):
    def setUp(self):
        # Deliberately reverse agent order; current index must refer to the
        # sorted display, not the order returned by agent.list.
        agents = [
            {"pane_id": "w2:p3", "workspace_id": "w2", "tab_id": "w2:t1",
             "agent": "pi", "agent_status": "done", "focused": False,
             "tokens": {"profile": "S/h", "elapsed": "2m", "session": "second"}},
            {"pane_id": "w1:p1", "workspace_id": "w1", "tab_id": "w1:t1",
             "agent": "pi", "focused": True, "tokens": {"session": "first"}},
        ]
        workspaces = [{"workspace_id": "w1", "label": "alpha"},
                      {"workspace_id": "w2", "label": "beta"}]
        tabs = [{"tab_id": "w1:t1", "number": 1, "label": "hidden-tab-alpha"},
                {"tab_id": "w2:t1", "number": 1, "label": "hidden-tab-beta"}]
        self.agents = agents
        self.tabs = tabs
        patches = [
            mock.patch.dict(os.environ, {}, clear=True),
            mock.patch.object(picker, "load_theme", return_value=({}, {}, "symbols")),
            mock.patch.object(picker, "herdr", side_effect=[
                {"agents": agents}, {"workspaces": workspaces}, {"tabs": tabs},
            ]),
        ]
        for patch in patches:
            patch.start()
            self.addCleanup(patch.stop)

    def assert_current(self, pane_id, index):
        entries, focused = picker.build_entries()
        marked = [entry_id for entry_id, text in entries if picker.CURRENT_ICON in text]
        self.assertTrue(all("[current]" not in text for _, text in entries))
        self.assertTrue(all("\n  pi" in text and "π" not in text for _, text in entries))
        self.assertTrue(all("hidden-tab-" not in text for _, text in entries))
        self.assertEqual(marked, [pane_id] if pane_id else [])
        self.assertEqual(focused, index)
        self.assertEqual([entry_id for entry_id, _ in entries], ["w1:p1", "w2:p3"])

    def test_task_name_is_bold_and_agent_type_is_on_second_row(self):
        entries, _ = picker.build_entries()
        first, second = dict(entries)["w2:p3"].split("\n", 1)
        self.assertIn(f"{picker.DIM}beta ·{picker.RESET}", first)
        self.assertIn(f"{picker.BOLD}second{picker.RESET}", first)
        self.assertNotIn("hidden-tab-beta", first)
        self.assertNotIn("pi", first)
        self.assertEqual(second.replace(picker.RESET, ""), "  pi · S/h · 2m")

    def test_missing_task_name_falls_back_to_tab_label(self):
        del self.agents[0]["tokens"]["session"]
        entries, _ = picker.build_entries()
        self.assertIn(f"{picker.BOLD}hidden-tab-beta{picker.RESET}", dict(entries)["w2:p3"])

    def test_blank_task_name_and_tab_label_fall_back_to_tab_number(self):
        self.agents[0]["tokens"]["session"] = "   "
        self.tabs[1]["label"] = ""
        entries, _ = picker.build_entries()
        self.assertIn(f"{picker.BOLD}1{picker.RESET}", dict(entries)["w2:p3"])

    def test_task_name_uses_bold_theme_text_color(self):
        with mock.patch.object(picker, "load_theme", return_value=({}, {"text": "#faf4ed"}, "symbols")):
            entries, _ = picker.build_entries()
        self.assertIn("\x1b[1;38;2;250;244;237msecond\x1b[0m", dict(entries)["w2:p3"])

    def test_completed_agent_row_shows_checkmark_separately_from_current_icon(self):
        os.environ["HERDR_ACTIVE_PANE_ID"] = "w2:p3"
        entries, focused = picker.build_entries()
        text = dict(entries)["w2:p3"]
        self.assertIn("✓", text)
        self.assertIn(picker.CURRENT_ICON, text)
        self.assertEqual(focused, 1)
        self.assertNotIn("✓", dict(entries)["w1:p1"])

    def test_popup_origin_overrides_inherited_pane_and_stale_server_focus(self):
        os.environ.update(HERDR_ACTIVE_PANE_ID="w2:p3", HERDR_PANE_ID="w1:p1")
        self.assert_current("w2:p3", 1)

    def test_direct_invocation_uses_calling_pane(self):
        os.environ["HERDR_PANE_ID"] = "w2:p3"
        self.assert_current("w2:p3", 1)

    def test_no_caller_context_falls_back_to_server_focus(self):
        self.assert_current("w1:p1", 0)

    def test_non_agent_or_closed_origin_does_not_mark_another_agent(self):
        os.environ["HERDR_ACTIVE_PANE_ID"] = "w9:p9"
        self.assert_current(None, 0)


class PickerTests(unittest.TestCase):
    def setUp(self):
        self.entries = [("w1:p1", "○ alpha · first\n  pi"), ("w2:p3", "◐ beta · second\n  pi")]
        patches = [
            mock.patch.object(picker, "build_entries", return_value=(self.entries, 1)),
            mock.patch.object(picker, "fzf_env", return_value={}),
            mock.patch.object(picker.sys, "argv", ["agent-picker.py"]),
        ]
        for patch in patches:
            patch.start()
            self.addCleanup(patch.stop)

    def test_enter_focuses_selected_pane_synchronously(self):
        selected = subprocess.CompletedProcess("fzf", 0, "w2:p3\n", "")
        with mock.patch.object(picker.subprocess, "run", return_value=selected) as fzf, \
             mock.patch.object(picker, "focus_pane") as focus, \
             mock.patch.object(picker.subprocess, "Popen") as background:
            self.assertEqual(picker.main(), 0)
        focus.assert_called_once_with("w2:p3")
        background.assert_not_called()
        cmd = fzf.call_args.args[0]
        self.assertIn("--accept-nth=1", cmd)
        self.assertIn("--sync", cmd)
        self.assertIn("--bind=start:pos(2)", cmd)
        self.assertIn("--pointer=", cmd)
        self.assertIn("--gutter= ", cmd)
        self.assertFalse(any(arg.startswith("--header=") for arg in cmd))
        self.assertIn("--preview-window=down,45%,border-top,wrap", cmd)
        self.assertTrue(any("ctrl-/:toggle-preview" in arg for arg in cmd))
        self.assertTrue(any("ctrl-r:refresh-preview" in arg for arg in cmd))
        self.assertTrue(any(arg.startswith("--preview=") and arg.endswith(" {1}") for arg in cmd))
        self.assertEqual(fzf.call_args.kwargs["input"],
                         "w1:p1\t○ alpha · first\n  pi\0w2:p3\t◐ beta · second\n  pi\0")

    def test_cancel_does_not_change_focus(self):
        for status in (1, 130):
            with self.subTest(status=status), \
                 mock.patch.object(picker.subprocess, "run", return_value=
                                   subprocess.CompletedProcess("fzf", status, "", "")), \
                 mock.patch.object(picker, "focus_pane") as focus:
                self.assertEqual(picker.main(), 0)
                focus.assert_not_called()

    def test_unexpected_selection_does_not_change_focus(self):
        selected = subprocess.CompletedProcess("fzf", 0, "unexpected\n", "")
        with mock.patch.object(picker.subprocess, "run", return_value=selected), \
             mock.patch.object(picker, "focus_pane") as focus:
            with self.assertRaisesRegex(picker.PickerError, "unexpected selection"):
                picker.main()
            focus.assert_not_called()

    def test_fzf_error_remains_visible_in_popup(self):
        failed = subprocess.CompletedProcess("fzf", 2, "", "invalid option")
        with mock.patch.object(picker.subprocess, "run", return_value=failed), \
             mock.patch.object(picker.sys.stdin, "isatty", return_value=True), \
             mock.patch("builtins.input") as dismiss, \
             contextlib.redirect_stderr(io.StringIO()) as stderr:
            self.assertEqual(picker.run(), 1)
        self.assertIn("invalid option", stderr.getvalue())
        dismiss.assert_called_once()


class ThemeTests(unittest.TestCase):
    def test_builtin_status_palette_and_user_override(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / "config.toml"
            config.write_text('[ui]\nstatus_indicators = "symbols"\n'
                              '[theme]\nname = "rose-pine-dawn"\n'
                              '[theme.custom]\nred = "#123456"\n')
            with mock.patch.object(picker, "CONFIG", str(config)):
                _, palette, indicators = picker.load_theme()
        self.assertEqual(indicators, "symbols")
        self.assertEqual(palette["red"], "#123456")
        self.assertEqual(palette["yellow"], "#ea9d34")
        self.assertEqual(palette["teal"], "#56949f")
        self.assertEqual(palette["green"], "#286983")
        self.assertEqual(palette["overlay0"], "#9893a5")
        self.assertEqual(picker.BUILTIN_STATUS_PALETTES["rose-pine-dawn"]["red"], "#b4637a")

    def test_default_indicator_style_is_herdr_dots_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / "config.toml"
            config.write_text('[theme]\nname = "kanagawa-lotus"\n')
            with mock.patch.object(picker, "CONFIG", str(config)):
                _, palette, indicators = picker.load_theme()
        self.assertEqual(indicators, "dots")
        self.assertEqual(palette["teal"], "#4e8ca2")

    def test_every_repo_theme_supplies_all_sidebar_status_colors(self):
        required = {key for _, key, _ in picker.STATUS.values()}
        for config in sorted((Path(picker.HERE) / "themes").glob("*.toml")):
            with self.subTest(theme=config.name), mock.patch.object(picker, "CONFIG", str(config)):
                _, palette, _ = picker.load_theme()
                self.assertTrue(required <= palette.keys(), f"missing colors: {required - palette.keys()}")

    def test_active_theme_does_not_inherit_old_gutter_or_layout(self):
        with tempfile.TemporaryDirectory() as tmp:
            theme = Path(tmp) / "theme with 'quotes'.sh"
            theme.write_text('export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --color=bg:#faf4ed"\n')
            inherited = {"FZF_DEFAULT_OPTS": "--color=gutter:#1f2335 --tac --query=wrong",
                         "FZF_DEFAULT_OPTS_FILE": "/old/options",
                         "HERDR_SOCKET_PATH": "/test/session.sock"}
            with mock.patch.dict(os.environ, inherited), \
                 mock.patch.object(picker, "FZF_THEME", str(theme)):
                env = picker.fzf_env()
        self.assertEqual(env["FZF_DEFAULT_OPTS"].strip(), "--color=bg:#faf4ed")
        self.assertNotIn("FZF_DEFAULT_OPTS_FILE", env)
        self.assertEqual(env["HERDR_SOCKET_PATH"], "/test/session.sock")

    def test_missing_theme_still_clears_stale_options(self):
        with mock.patch.dict(os.environ, {"FZF_DEFAULT_OPTS": "--color=gutter:#000000"}), \
             mock.patch.object(picker.os.path, "isfile", return_value=False):
            self.assertEqual(picker.fzf_env()["FZF_DEFAULT_OPTS"], "")


class PathDisplayTests(unittest.TestCase):
    def test_home_and_descendants_use_tilde(self):
        with mock.patch.dict(os.environ, {"HOME": "/Users/mni"}):
            self.assertEqual(picker.display_path("/Users/mni"), "~")
            self.assertEqual(picker.display_path("/Users/mni/workspace/my repo"), "~/workspace/my repo")

    def test_similar_prefixes_and_embedded_home_are_not_abbreviated(self):
        paths = ("/Users/mni-backup/repo", "/Users/other/repo", "/tmp/Users/mni/repo")
        with mock.patch.dict(os.environ, {"HOME": "/Users/mni"}):
            for path in paths:
                with self.subTest(path=path):
                    self.assertEqual(picker.display_path(path), path)


class RecentOutputTests(unittest.TestCase):
    def test_reads_only_the_selected_agent_and_bounds_output(self):
        text = "\n".join(f"line-{i}" for i in range(20)) + "\n\n"
        with mock.patch.object(picker.subprocess, "check_output", return_value=text) as lookup, \
             mock.patch.object(picker, "focus_pane") as focus:
            output = picker.recent_output("w2:p3")
        lookup.assert_called_once_with(
            [picker.HERDR, "agent", "read", "w2:p3", "--source", "recent-unwrapped",
             "--lines", "12", "--format", "text"], text=True, stderr=subprocess.PIPE, timeout=5,
        )
        self.assertEqual(output.splitlines(), [f"line-{i}" for i in range(8, 20)])
        focus.assert_not_called()

    def test_controls_are_not_replayed(self):
        with mock.patch.object(picker.subprocess, "check_output", return_value="a\t\x1b]52;secret\x07\nnext"):
            output = picker.recent_output("w2:p3")
        self.assertNotIn("\x1b", output)
        self.assertNotIn("\x07", output)
        self.assertNotIn("\t", output)
        self.assertIn("\nnext", output)

    def test_empty_and_unavailable_output_are_nonfatal(self):
        with mock.patch.object(picker.subprocess, "check_output", return_value="\n  "):
            self.assertEqual(picker.recent_output("w2:p3"), "(no output yet)")
        with mock.patch.object(picker.subprocess, "check_output", side_effect=subprocess.TimeoutExpired("herdr", 5)):
            self.assertEqual(picker.recent_output("w2:p3"), "(output unavailable)")


class PreviewTests(unittest.TestCase):
    def setUp(self):
        patch = mock.patch.object(picker, "recent_output", return_value="last terminal line")
        self.output = patch.start()
        self.addCleanup(patch.stop)

    def test_recent_output_is_appended_after_git_details(self):
        with mock.patch.object(picker, "herdr", return_value={"agent": {}}):
            text = picker.render_details("w2:p3")
        self.output.assert_called_once_with("w2:p3")
        self.assertIn("Recent output", text)
        self.assertTrue(text.endswith("last terminal line"))

    def test_home_abbreviation_is_display_only(self):
        cwd = "/Users/mni/worktree/src"
        with mock.patch.dict(os.environ, {"HOME": "/Users/mni"}), \
             mock.patch.object(picker, "herdr", return_value={"agent": {"foreground_cwd": cwd}}), \
             mock.patch.object(picker, "git_details", return_value=("topic", "~/worktree (linked)")) as git:
            text = picker.render_details("w2:p3")
        git.assert_called_once_with(cwd)
        self.assertIn("~/worktree/src", text)
        self.assertNotIn("/Users/mni", text)

    def test_uses_foreground_cwd_and_keeps_full_path(self):
        agent = {"cwd": "/old/root", "foreground_cwd": "/full/path/to/worktree/src"}
        with mock.patch.object(picker, "herdr", return_value={"agent": agent}) as lookup, \
             mock.patch.object(picker, "git_details", return_value=("feature/topic", "/full/path/to/worktree (linked)")) as git:
            text = picker.render_details("w2:p3")
        lookup.assert_called_once_with("agent", "get", "w2:p3")
        git.assert_called_once_with(agent["foreground_cwd"])
        for value in ("Branch", "feature/topic", "Worktree", "(linked)", "PWD", agent["foreground_cwd"]):
            self.assertIn(value, text)
        self.assertNotIn("/old/root", text)

    def test_cwd_fallback_when_no_foreground_directory(self):
        with mock.patch.object(picker, "herdr", return_value={"agent": {"cwd": "/root"}}), \
             mock.patch.object(picker, "git_details", return_value=("—", "—")) as git:
            self.assertIn("/root", picker.render_details("w2:p3"))
        git.assert_called_once_with("/root")

    def test_missing_cwd_does_not_query_git(self):
        with mock.patch.object(picker, "herdr", return_value={"agent": {}}), \
             mock.patch.object(picker, "git_details") as git:
            self.assertIn("PWD", picker.render_details("w2:p3"))
        git.assert_not_called()

    def test_preview_mode_never_opens_fzf_or_changes_focus(self):
        with mock.patch.object(picker.sys, "argv", ["agent-picker.py", "--preview", "w2:p3"]), \
             mock.patch.object(picker, "render_details", return_value="details") as preview, \
             mock.patch.object(picker, "build_entries") as listing, \
             mock.patch.object(picker, "focus_pane") as focus, \
             contextlib.redirect_stdout(io.StringIO()) as stdout:
            self.assertEqual(picker.main(), 0)
        preview.assert_called_once_with("w2:p3")
        listing.assert_not_called()
        focus.assert_not_called()
        self.assertEqual(stdout.getvalue(), "details\n")

    def test_preview_strips_terminal_controls_from_metadata(self):
        with mock.patch.object(picker, "herdr", return_value={"agent": {"cwd": "/tmp/\x1b]52;secret\x07"}}), \
             mock.patch.object(picker, "git_details", return_value=("topic\n\x1b[31m", "tree\x07")):
            text = picker.render_details("w2:p3")
        self.assertNotIn("\x1b]52", text)
        self.assertNotIn("\x1b[31m", text)
        self.assertNotIn("\x07", text)
        self.assertEqual(text.split("\n\n", 1)[0].count("\n"), 2)


@unittest.skipUnless(shutil.which("git"), "Git not installed")
class GitDetailsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="picker-git-", dir="/tmp")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.repo = self.root / "repo with spaces"
        self.env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        self.env.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        subprocess.run(["git", "init", "-b", "main", str(self.repo)], env=self.env,
                       check=True, capture_output=True)

    def git(self, *args):
        return subprocess.check_output(
            ["git", "-C", str(self.repo), *args], env=self.env, stderr=subprocess.DEVNULL, text=True,
        ).strip()

    def commit_fixture(self):
        self.git("-c", "user.name=Picker Test", "-c", "user.email=picker@example.invalid",
                 "-c", "commit.gpgsign=false", "-c", f"core.hooksPath={os.devnull}",
                 "commit", "--allow-empty", "-m", "test fixture")

    def test_main_worktree_and_unborn_branch_from_subdirectory(self):
        subdir = self.repo / "src"
        subdir.mkdir()
        self.assertEqual(picker.git_details(str(subdir)), ("main", f"{self.repo.resolve()} (main)"))

    def test_worktree_root_under_home_is_abbreviated(self):
        with mock.patch.dict(os.environ, {"HOME": str(self.root.resolve())}):
            self.assertEqual(picker.git_details(str(self.repo)), ("main", "~/repo with spaces (main)"))

    def test_linked_worktree_has_its_own_branch(self):
        self.commit_fixture()
        linked = self.root / "linked worktree"
        self.git("worktree", "add", "-b", "feature/picker", str(linked))
        self.assertEqual(picker.git_details(str(linked)),
                         ("feature/picker", f"{linked.resolve()} (linked)"))

    def test_detached_head(self):
        self.commit_fixture()
        self.git("checkout", "--detach", "HEAD")
        branch, worktree = picker.git_details(str(self.repo))
        self.assertEqual(branch, f"detached @ {self.git('rev-parse', '--short', 'HEAD')}")
        self.assertIn("(main)", worktree)

    def test_non_git_and_missing_directory_are_harmless(self):
        self.assertEqual(picker.git_details(str(self.root)), ("—", "—"))
        self.assertEqual(picker.git_details(str(self.root / "missing")), ("—", "—"))

    def test_inherited_git_directory_cannot_override_selected_checkout(self):
        with mock.patch.dict(os.environ, {"GIT_DIR": "/missing/git-dir", "GIT_WORK_TREE": "/wrong/tree"}):
            self.assertEqual(picker.git_details(str(self.repo))[0], "main")

    def test_slow_git_returns_unavailable_instead_of_hanging(self):
        with mock.patch.object(picker.subprocess, "run", side_effect=subprocess.TimeoutExpired("git", 1.5)):
            self.assertEqual(picker.git_details(str(self.repo)), ("— (Git unavailable)", "—"))


if __name__ == "__main__":
    unittest.main()
