#!/opt/homebrew/bin/python3
"""Sidebar-style agent picker for Herdr, meant to run as a `[[keys.command]]` popup.

Herdr's built-in session navigator (prefix+g) shows the whole
workspace → tab → pane tree and is not configurable. This picker renders
workspace + bold session/task name on the first row (falling back to the tab
name), and agent type/profile/elapsed on the second.
Colors are read from `ui.sidebar.agents.rows` in the generated config.toml,
so they follow the active theme. Selection uses the socket `pane.focus` API.
`◆` marks the pane that opened the picker, independently of selection.
Ctrl+/ toggles details (Git context and the last 12 terminal lines).
Ctrl+r refreshes this read-only preview without focusing the pane.
Git metadata and terminal output are read only when details are shown.

Usage:
  agent-picker.py                 # interactive (fzf)
  agent-picker.py --list          # print entries and exit (debugging)
  agent-picker.py --preview PANE  # render details (used by fzf)
"""

from __future__ import annotations

import json
import os
import shlex
import socket
import subprocess
import sys
import tomllib

# Popup shells can start with a minimal PATH; make sure fzf/herdr are reachable.
os.environ["PATH"] = ":".join(
    dict.fromkeys(
        ["/opt/homebrew/bin", os.path.expanduser("~/.local/bin"), *os.environ.get("PATH", "").split(":")]
    )
)

HERE = os.path.dirname(os.path.realpath(__file__))
HERDR = os.environ.get("HERDR_BIN_PATH", "herdr")
CONFIG = os.path.join(HERE, "config.toml")
FZF_THEME = os.path.expanduser("~/.config/themes/current_fzf_theme")

RESET = "\x1b[0m"
DIM = "\x1b[2m"
BOLD = "\x1b[1m"
CURRENT_ICON = "◆"

# Match Herdr v0.9.0 src/client/shell.rs status_icon/status_color:
# agent_status -> (symbols-mode glyph, palette key, terminal-palette fallback).
STATUS = {
    "working": ("◐", "yellow", "\x1b[33m"),
    "blocked": ("×", "red", "\x1b[31m"),
    "done": ("✓", "teal", "\x1b[36m"),
    "idle": ("○", "green", "\x1b[32m"),
    "unknown": ("·", "overlay0", "\x1b[90m"),
}

# The two built-in themes used by this repo do not serialize their palettes
# into config.toml. These status colors come from Herdr v0.9.0 src/app/state.rs.
# All other repo themes define these keys explicitly in theme.custom.
BUILTIN_STATUS_PALETTES = {
    "rose-pine-dawn": {
        "yellow": "#ea9d34", "red": "#b4637a", "teal": "#56949f",
        "green": "#286983", "overlay0": "#9893a5",
    },
    "kanagawa-lotus": {
        "yellow": "#77713f", "red": "#c84053", "teal": "#4e8ca2",
        "green": "#6f894e", "overlay0": "#a09cac",
    },
}


class PickerError(Exception):
    """A failure that should remain visible until the user dismisses the popup."""


def herdr(*args: str) -> dict:
    out = subprocess.check_output([HERDR, *args], text=True, timeout=5)
    return json.loads(out)["result"]


def focus_pane(pane_id: str) -> None:
    # In Herdr 0.9.0, public agent.focus changes server state but is missing
    # from the client-location projection in server/headless/client_views.rs.
    # pane.focus updates both. The CLI's `pane focus` only accepts a direction,
    # so use the documented newline-delimited socket API for an exact pane ID.
    # The popup injects this path; never guess another session's socket.
    path = os.environ.get("HERDR_SOCKET_PATH")
    if not path:
        raise PickerError("HERDR_SOCKET_PATH is missing; open this picker inside Herdr.")
    request = {
        "id": "agent-picker:focus",
        "method": "pane.focus",
        "params": {"pane_id": pane_id},
    }
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(5)
        client.connect(path)
        client.sendall((json.dumps(request) + "\n").encode())
        with client.makefile("rb") as response_file:
            raw = response_file.readline(1024 * 1024)
    if not raw.endswith(b"\n"):
        raise PickerError("Herdr returned an incomplete focus response.")
    response = json.loads(raw)
    if response.get("id") != request["id"]:
        raise PickerError("Herdr returned a mismatched focus response.")
    if "error" in response:
        error = response["error"]
        raise PickerError(f"{error.get('code', 'focus_failed')}: {error.get('message', error)}")
    pane = response.get("result", {}).get("pane", {})
    if pane.get("pane_id") != pane_id or not pane.get("focused"):
        raise PickerError("Herdr did not confirm focus on the selected pane.")


def hex_sgr(value: str, bold: bool = False) -> str:
    h = value.lstrip("#")
    if len(h) != 6:
        return BOLD if bold else ""
    r, g, b = (int(h[i : i + 2], 16) for i in (0, 2, 4))
    return f"\x1b[{'1;' if bold else ''}38;2;{r};{g};{b}m"


def load_theme() -> tuple[dict[str, str], dict[str, str], str]:
    """Return token styles, effective status palette, and indicator style."""
    try:
        with open(CONFIG, "rb") as fh:
            cfg = tomllib.load(fh)
    except (OSError, tomllib.TOMLDecodeError):
        cfg = {}
    styles: dict[str, str] = {}
    rows = cfg.get("ui", {}).get("sidebar", {}).get("agents", {}).get("rows", [])
    for row in rows:
        for cell in row:
            if isinstance(cell, dict) and cell.get("token"):
                sgr = hex_sgr(cell.get("fg", ""), bool(cell.get("bold")))
                if cell.get("dim"):
                    sgr += DIM
                styles[cell["token"]] = sgr
    theme = cfg.get("theme", {})
    palette = dict(BUILTIN_STATUS_PALETTES.get(theme.get("name"), {}))
    palette.update(theme.get("custom", {}))
    indicators = cfg.get("ui", {}).get("status_indicators", "dots")
    return styles, palette, indicators


def paint(styles: dict[str, str], token: str, text: str) -> str:
    if not text:
        return ""
    return f"{styles.get(token, '')}{text}{RESET}"


def status_icon(status: str, palette: dict[str, str], indicators: str = "symbols") -> str:
    glyph, key, fallback = STATUS.get(status, STATUS["unknown"])
    if indicators == "dots" and status in ("working", "blocked", "done"):
        glyph = "●"
    color = hex_sgr(palette[key]) if key in palette else fallback
    return f"{color}{glyph}{RESET}"


def display_path(path: str) -> str:
    """Abbreviate only the leading home directory; leave lookup paths intact."""
    home = os.path.expanduser("~")
    if path == home:
        return "~"
    prefix = home.rstrip(os.sep) + os.sep
    if os.path.isabs(home) and path.startswith(prefix):
        return "~/" + path[len(prefix):]
    return path


def git_details(cwd: str) -> tuple[str, str]:
    """Return branch/worktree labels without scanning files or changing Git state."""
    # Inspect this agent's checkout, not GIT_DIR/GIT_WORK_TREE inherited from
    # the pane that opened the picker. Do not override Git's trust checks.
    env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}

    def git(*args: str) -> str | None:
        result = subprocess.run(
            ["git", "--no-optional-locks", "-C", cwd, *args],
            text=True, capture_output=True, timeout=1.5, env=env,
        )
        return result.stdout.rstrip("\n") if result.returncode == 0 else None

    try:
        checkout = git("rev-parse", "--path-format=absolute", "--show-toplevel",
                       "--git-dir", "--git-common-dir")
        if not checkout or len(paths := checkout.splitlines()) != 3:
            return "—", "—"
        root, git_dir, common_dir = paths
        branch = git("symbolic-ref", "--quiet", "--short", "HEAD")
        if not branch:
            revision = git("rev-parse", "--short", "HEAD")
            branch = f"detached @ {revision}" if revision else "—"
        kind = "linked" if os.path.realpath(git_dir) != os.path.realpath(common_dir) else "main"
        return branch, f"{display_path(root)} ({kind})"
    except (OSError, subprocess.TimeoutExpired):
        return "— (Git unavailable)", "—"


def recent_output(pane_id: str) -> str:
    """A bounded, plain-text snapshot; reading does not focus or mark an agent seen."""
    try:
        # Unlike agent get/list, the CLI's agent read prints terminal text,
        # not a JSON envelope. Do not pass it through the herdr() JSON helper.
        text = subprocess.check_output(
            [HERDR, "agent", "read", pane_id, "--source", "recent-unwrapped",
             "--lines", "12", "--format", "text"],
            text=True, stderr=subprocess.PIPE, timeout=5,
        )
    except (OSError, subprocess.SubprocessError, ValueError, KeyError):
        return "(output unavailable)"
    lines = text.rstrip().splitlines()[-12:]
    # Never replay terminal controls from another pane into fzf's preview.
    clean = "\n".join(
        "".join(char if char.isprintable() else " " for char in line.expandtabs(4))[:4096]
        for line in lines
    )
    return clean or "(no output yet)"


def render_details(pane_id: str) -> str:
    agent = herdr("agent", "get", pane_id)["agent"]
    cwd = agent.get("foreground_cwd") or agent.get("cwd")
    branch, worktree = git_details(cwd) if cwd else ("—", "—")
    rows = [("Branch", branch), ("Worktree", worktree), ("PWD", display_path(cwd) if cwd else "—")]
    # Process metadata and paths can contain terminal controls. Show only text
    # in the preview; none of these values is interpolated into a shell command.
    metadata = "\n".join(
        f"{DIM}{label:<9}{RESET}" + "".join(char if char.isprintable() else " " for char in value)
        for label, value in rows
    )
    return f"{metadata}\n\n{DIM}── Recent output ──{RESET}\n{recent_output(pane_id)}"


def build_entries() -> tuple[list[tuple[str, str]], int]:
    """Return ([(pane_id, rendered)], index of the focused agent)."""
    styles, palette, indicators = load_theme()
    agents = herdr("agent", "list")["agents"]
    workspaces = herdr("workspace", "list")["workspaces"]
    tabs = herdr("tab", "list")["tabs"]

    # Pin "current" to the pane that opened this popup. Server-global focus
    # can differ from this client's view; moving the fzf cursor isn't a focus
    # change either. Only fall back to the server flag without caller context.
    current_pane_id = (
        os.environ.get("HERDR_ACTIVE_PANE_ID")
        or os.environ.get("HERDR_PANE_ID")
        or next((a["pane_id"] for a in agents if a.get("focused")), None)
    )

    ws_order = {w["workspace_id"]: i for i, w in enumerate(workspaces)}
    ws_label = {w["workspace_id"]: w.get("label") or w["workspace_id"] for w in workspaces}
    tab_number = {t["tab_id"]: t.get("number", 0) for t in tabs}
    tab_label = {
        t["tab_id"]: (t.get("label") or "").strip() or str(t.get("number") or "")
        for t in tabs
    }

    # Mirror `ui.agent_panel_sort = "spaces"`: sidebar workspace order, then tab.
    agents.sort(
        key=lambda a: (
            ws_order.get(a["workspace_id"], len(ws_order)),
            tab_number.get(a["tab_id"], 0),
            a["pane_id"],
        )
    )

    entries: list[tuple[str, str]] = []
    focused = 0
    # The task name is the primary identifier: bold theme text, rather than
    # the subdued agent-type/session token colors used in the sidebar.
    name_style = hex_sgr(palette.get("text", ""), bold=True)
    for i, a in enumerate(agents):
        tokens = a.get("tokens") or {}
        is_current = a["pane_id"] == current_pane_id
        agent_type = a.get("agent") or "?"
        task_name = (tokens.get("session") or "").strip() or tab_label.get(a["tab_id"]) or "untitled"
        workspace = ws_label.get(a["workspace_id"], a["workspace_id"])
        line1 = " ".join(
            part
            for part in (
                status_icon(a.get("agent_status", "unknown"), palette, indicators),
                f"{DIM}{workspace} ·{RESET}",
                f"{name_style}{task_name}{RESET}",
                f"{BOLD}{CURRENT_ICON}{RESET}" if is_current else "",
            )
            if part
        )
        line2 = " · ".join(
            part
            for part in (
                paint(styles, "agent", agent_type),
                paint(styles, "$profile", tokens.get("profile", "")),
                paint(styles, "$elapsed", tokens.get("elapsed", "")),
            )
            if part
        )
        entries.append((a["pane_id"], f"{line1}\n  {line2}"))
        if is_current:
            focused = i
    return entries, focused


def fzf_env() -> dict[str, str]:
    """Use the current theme, not accumulated options from older shell themes."""
    env = dict(os.environ)
    # The server may still carry a dark-theme gutter after switching to light.
    # This picker owns its layout/bindings; only import the active theme's opts.
    env["FZF_DEFAULT_OPTS"] = ""
    env.pop("FZF_DEFAULT_OPTS_FILE", None)
    if os.path.isfile(FZF_THEME):
        try:
            env["FZF_DEFAULT_OPTS"] = subprocess.check_output(
                ["sh", "-c", '. "$1" && printf %s "$FZF_DEFAULT_OPTS"', "sh", FZF_THEME],
                text=True, stderr=subprocess.DEVNULL, env=env, timeout=2,
            )
        except (OSError, subprocess.SubprocessError):
            pass
    return env


def main() -> int:
    if sys.argv[1:2] == ["--preview"]:
        if len(sys.argv) != 3:
            raise PickerError("usage: agent-picker.py --preview PANE")
        print(render_details(sys.argv[2]))
        return 0

    entries, focused = build_entries()
    if not entries:
        print("no agents", file=sys.stderr)
        return 1

    if "--list" in sys.argv[1:]:
        for pane_id, text in entries:
            print(f"{pane_id}\t{text}")
        return 0

    payload = "\0".join(f"{pane_id}\t{text}" for pane_id, text in entries) + "\0"
    cmd = [
        "fzf",
        "--read0",
        # start:pos needs the input list to exist. Without --sync, the start
        # event races the piped input and can silently select the wrong agent.
        "--sync",
        "--ansi",
        "--delimiter=\t",
        "--with-nth=2",
        "--accept-nth=1",
        "--layout=reverse",
        "--highlight-line",
        "--gap=1",
        "--gap-line=",
        "--cycle",
        "--no-info",
        "--no-separator",
        "--no-scrollbar",
        "--border=none",
        "--prompt=agents › ",
        "--pointer=",
        "--gutter= ",
        "--preview=" + shlex.join([sys.executable, os.path.realpath(__file__), "--preview"]) + " {1}",
        "--preview-window=down,45%,border-top,wrap",
        "--preview-label= details ",
        f"--bind=start:pos({focused + 1})",
        "--bind=ctrl-j:down,ctrl-k:up,ctrl-/:toggle-preview,ctrl-r:refresh-preview",
    ]
    proc = subprocess.run(cmd, input=payload, text=True, capture_output=True, env=fzf_env())
    if proc.returncode in (1, 130):  # Esc / ctrl-c / no match
        return 0
    if proc.returncode != 0:
        raise PickerError(f"fzf failed ({proc.returncode}): {proc.stderr.strip()}")
    pane_id = proc.stdout.strip()
    if not pane_id:
        return 0
    if pane_id not in dict(entries):
        raise PickerError(f"fzf returned an unexpected selection: {pane_id!r}")
    focus_pane(pane_id)
    return 0


def run() -> int:
    try:
        return main()
    except (PickerError, OSError, subprocess.SubprocessError, ValueError, KeyError) as exc:
        print(f"Agent picker: {exc}", file=sys.stderr, flush=True)
        # Keep errors visible in the popup, instead of silently disappearing.
        if sys.stdin.isatty():
            try:
                input("Press Enter to close… ")
            except (EOFError, KeyboardInterrupt):
                pass
        return 1


if __name__ == "__main__":
    sys.exit(run())
