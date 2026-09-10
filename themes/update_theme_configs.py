#!/usr/bin/env python3
"""Atomically update theme settings that have no supported non-interactive CLI."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import stat
import tempfile


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    file_descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(file_descriptor, "w", encoding="utf-8") as handle:
            handle.write(content)
        os.chmod(temporary_path, mode)
        os.replace(temporary_path, path)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()


def update_codex(path: Path, theme: str) -> None:
    content = path.read_text(encoding="utf-8") if path.exists() else ""
    table_match = re.search(r"(?m)^\[tui\][ \t]*$", content)
    setting = f'theme = "{theme}"'

    if table_match:
        table_start = table_match.end()
        next_table = re.search(r"(?m)^\[", content[table_start:])
        table_end = table_start + next_table.start() if next_table else len(content)
        table_body = content[table_start:table_end]
        theme_match = re.search(r"(?m)^[ \t]*theme[ \t]*=.*$", table_body)
        if theme_match:
            start = table_start + theme_match.start()
            end = table_start + theme_match.end()
            content = content[:start] + setting + content[end:]
        else:
            content = content[:table_start] + f"\n{setting}" + content[table_start:]
    else:
        separator = "" if not content else ("\n" if content.endswith("\n") else "\n\n")
        content += f"{separator}[tui]\n{setting}\n"

    atomic_write(path, content)


def update_json_string_setting(content: str, key: str, value: str) -> str:
    encoded_value = json.dumps(value, ensure_ascii=False)
    setting_pattern = re.compile(
        rf'("{re.escape(key)}"\s*:\s*)"(?:\\.|[^"\\])*"'
    )

    if setting_pattern.search(content):
        return setting_pattern.sub(rf"\g<1>{encoded_value}", content, count=1)

    closing_brace = content.rfind("}")
    if closing_brace < 0:
        raise ValueError("JSON settings file has no closing object brace")
    before = content[:closing_brace].rstrip()
    comma = "" if before.endswith("{") else ","
    indentation_match = re.search(r'(?m)^([ \t]+)"', content)
    indentation = indentation_match.group(1) if indentation_match else "  "
    return (
        before
        + comma
        + f"\n{indentation}{json.dumps(key)}: {encoded_value}\n"
        + content[closing_brace:]
    )


def update_vscode(path: Path, theme: str, variant: str | None) -> None:
    content = path.read_text(encoding="utf-8") if path.exists() else "{}\n"
    content = update_json_string_setting(content, "workbench.colorTheme", theme)

    if variant:
        content = update_json_string_setting(
            content, "everforest.lightContrast", variant
        )

    atomic_write(path, content)


def update_pi(path: Path, theme: str) -> None:
    content = path.read_text(encoding="utf-8") if path.exists() else "{}\n"
    content = update_json_string_setting(content, "theme", theme)
    atomic_write(path, content)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("application", choices=("codex", "pi", "vscode"))
    parser.add_argument("--file", required=True, type=Path)
    parser.add_argument("--theme", required=True)
    parser.add_argument("--variant")
    arguments = parser.parse_args()

    if arguments.application == "codex":
        update_codex(arguments.file, arguments.theme)
    elif arguments.application == "pi":
        update_pi(arguments.file, arguments.theme)
    else:
        update_vscode(arguments.file, arguments.theme, arguments.variant)


if __name__ == "__main__":
    main()
