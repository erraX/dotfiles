#!/opt/homebrew/bin/python3
"""Polling-based turn durations for Herdr's $elapsed display token.

Called by agent-elapsed-tracker.sh with an agent-list snapshot on stdin.
Working time accumulates; blocked/unknown pauses it; done/idle preserves the
final duration until the next observed working turn. No lifecycle is reported
or inferred from the duration. Transitions between polls cannot be recovered.
"""
from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


SOURCE = "user:elapsed-tracker"


def identity(agent: dict) -> dict:
    return {
        "terminal": agent.get("terminal_id"),
        "agent": agent.get("agent"),
        "session": (agent.get("agent_session") or {}).get("value"),
    }


def advance(previous: dict | None, agent: dict, now: int) -> dict | None:
    occupant = identity(agent)
    if previous and any(
        old and occupant.get(key) and old != occupant[key]
        for key, old in previous.get("identity", {}).items()
    ):
        previous = None
    status = agent.get("agent_status", "unknown")
    if previous is None:
        if status != "working":
            return None  # No observed turn: do not invent a duration.
        return {"identity": occupant, "status": status, "seconds": 0, "since": now, "finished": False}

    turn = dict(previous)
    turn.setdefault("finished", turn["status"] in ("done", "idle"))
    turn["identity"] = {key: occupant.get(key) or value
                        for key, value in previous.get("identity", occupant).items()}
    since = turn.get("since")
    if since is not None and status != "working":
        turn["seconds"] += max(0, now - since)
        turn["since"] = None
    elif since is None and status == "working":
        if turn["finished"]:
            turn["seconds"] = 0  # A new turn, not a blocked-turn continuation.
        turn["since"] = now
        turn["finished"] = False
    if status in ("done", "idle"):
        turn["finished"] = True
    turn["status"] = status
    return turn


def elapsed_label(turn: dict, now: int) -> str:
    seconds = turn["seconds"]
    if turn.get("since") is not None:
        seconds += max(0, now - turn["since"])
    # Preserve the sidebar's existing compact format and polling precision.
    return "<1m" if seconds < 60 else f"{seconds // 60}m"


def plan(state: dict, agents: list[dict], now: int) -> tuple[dict, dict[str, str | None]]:
    state = copy.deepcopy(state)
    old_turns = state.get("turns", {})
    legacy_starts = state.get("starts", {})
    labels = state.setdefault("labels", {})
    turns = {}
    updates = {}
    live = {agent["pane_id"] for agent in agents}

    for agent in agents:
        pane = agent["pane_id"]
        previous = old_turns.get(pane)
        if previous is None and pane in legacy_starts:
            # Keep the current in-flight duration when upgrading the old script.
            previous = {"identity": identity(agent), "status": "working",
                        "seconds": 0, "since": legacy_starts[pane]}
        turn = advance(previous, agent, now)
        observed = (agent.get("tokens") or {}).get("elapsed")
        if turn is None:
            if pane in labels or observed is not None:
                updates[pane] = None
            labels.pop(pane, None)
            continue
        turns[pane] = turn
        label = elapsed_label(turn, now)
        # Re-report a missing/expired token, even when its text hasn't changed.
        # A migrated turn has no reported label, forcing removal of the old TTL.
        if turn.get("reported") != label or observed != label:
            updates[pane] = label

    for pane in (set(old_turns) | set(legacy_starts) | set(labels)) - live:
        updates[pane] = None
        labels.pop(pane, None)
    state["turns"] = turns
    state["starts"] = {}  # migrated; retained as an empty compatibility field
    return state, updates


def save_state(path: Path, state: dict) -> None:
    # Other fields belong to the profile/session tracker; keep its latest data.
    latest = json.loads(path.read_text()) if path.exists() else {}
    for key in ("turns", "starts", "labels"):
        latest[key] = state[key]
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent,
                                         prefix=".agent-elapsed-state.", delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(latest, stream, indent=2)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def publish(herdr: str, pane: str, label: str | None) -> bool:
    command = [herdr, "pane", "report-metadata", pane, "--source", SOURCE]
    command += ["--clear-token", "elapsed"] if label is None else ["--token", f"elapsed={label}"]
    # No TTL: setting a token without one also removes the old 90-second TTL.
    # It remains visible until the next turn or until this occupant disappears.
    try:
        result = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1)
        return result.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def tick(path: Path, agents: list[dict], now: int, herdr: str) -> None:
    original = json.loads(path.read_text()) if path.exists() else {}
    state, updates = plan(original, agents, now)
    # Persist observed transitions before reporting so a slow API cannot lose a
    # completed turn if the host's command timeout interrupts this invocation.
    save_state(path, state)
    acknowledged = False
    for pane, label in updates.items():
        if publish(herdr, pane, label) and label is not None:
            state["turns"][pane]["reported"] = label
            state["labels"][pane] = label
            acknowledged = True
    if acknowledged:
        save_state(path, state)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: agent-turn-timer.py STATE_FILE < agent-list.json", file=sys.stderr)
        return 2
    agents = json.load(sys.stdin)["result"]["agents"]
    if not isinstance(agents, list):
        raise ValueError("invalid agent snapshot")
    tick(Path(sys.argv[1]), agents, int(time.time()), os.environ.get("HERDR_BIN_PATH", "herdr"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
