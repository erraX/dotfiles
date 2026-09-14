"""Themed popup launcher tests; all child commands run in temporary directories."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / "themes" / "with-fzf-theme.sh"
CAPTURE = '''import json, os, sys
print(json.dumps({"opts": os.environ.get("FZF_DEFAULT_OPTS"),
                  "opts_file": os.environ.get("FZF_DEFAULT_OPTS_FILE"),
                  "cwd": os.getcwd(), "args": sys.argv[1:],
                  "socket": os.environ.get("HERDR_SOCKET_PATH")}))'''


class ToolPopupThemeTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="popup-theme-", dir="/tmp")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.home = self.root / "home with spaces"
        self.theme = self.home / ".config" / "themes" / "current_fzf_theme"
        self.theme.parent.mkdir(parents=True)
        self.cwd = self.root / "agent directory"
        self.cwd.mkdir()
        self.env = dict(os.environ, HOME=str(self.home),
                        FZF_DEFAULT_OPTS="--color=bg:#1f2335 --color=gutter:#1f2335 --color=query:#c0caf5",
                        FZF_DEFAULT_OPTS_FILE="/old/options/file",
                        HERDR_SOCKET_PATH="/test/herdr.sock")

    def capture(self):
        output = subprocess.check_output(
            ["sh", str(LAUNCHER), sys.executable, "-c", CAPTURE, "file with spaces", "literal'quote"],
            env=self.env, cwd=self.cwd, text=True, timeout=5,
        )
        return json.loads(output)

    def test_discards_stale_colors_and_uses_current_theme(self):
        self.theme.write_text('export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --color=fg:#d3c6aa,bg:#2d353b"\n')
        result = self.capture()
        self.assertIn("fg:#d3c6aa,bg:#2d353b", result["opts"])
        self.assertIn("--layout=reverse", result["opts"])
        self.assertNotIn("#1f2335", result["opts"])
        self.assertNotIn("query:", result["opts"])
        self.assertIsNone(result["opts_file"])

    def test_preserves_cwd_arguments_and_session(self):
        result = self.capture()
        self.assertEqual(result["cwd"], str(self.cwd.resolve()))
        self.assertEqual(result["args"], ["file with spaces", "literal'quote"])
        self.assertEqual(result["socket"], "/test/herdr.sock")

    def test_theme_is_reloaded_on_every_launch(self):
        self.theme.write_text('export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --color=bg:#2d353b"\n')
        self.assertIn("#2d353b", self.capture()["opts"])
        self.theme.write_text('export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --color=bg:#faf4ed"\n')
        changed = self.capture()["opts"]
        self.assertIn("#faf4ed", changed)
        self.assertNotIn("#2d353b", changed)

    def test_missing_theme_does_not_reuse_old_colors(self):
        self.assertNotIn("--color", self.capture()["opts"])

    def test_child_exit_status_is_preserved(self):
        result = subprocess.run(["sh", str(LAUNCHER), "sh", "-c", "exit 7"], env=self.env)
        self.assertEqual(result.returncode, 7)

    def test_command_is_required(self):
        result = subprocess.run(["sh", str(LAUNCHER)], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("Usage:", result.stderr)

    def test_yazi_binding_uses_launcher(self):
        config = tomllib.loads((ROOT / "herdr" / "config.base.toml").read_text())
        binding = next(item for item in config["keys"]["command"] if item["key"] == "prefix+f")
        self.assertEqual(binding["type"], "popup")
        self.assertTrue(binding["command"].endswith("themes/with-fzf-theme.sh /opt/homebrew/bin/yazi"))


if __name__ == "__main__":
    unittest.main()
