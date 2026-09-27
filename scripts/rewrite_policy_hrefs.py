#!/usr/bin/env python3
"""Rewrite absolute /vendor|/odm policy hrefs to local basenames when present in FIX dir."""
from pathlib import Path
import re
import sys


def rewrite(fix: Path) -> int:
    changed = 0
    for xml in sorted(fix.glob("*.xml")):
        text = xml.read_text(encoding="utf-8")

        def repl(match: re.Match) -> str:
            href = match.group(1)
            if href.startswith("/vendor/etc/") or href.startswith("/odm/etc/"):
                base = href.rsplit("/", 1)[-1]
                if (fix / base).exists():
                    return f'href="{base}"'
            return match.group(0)

        new = re.sub(r'href="([^"]+)"', repl, text)
        if new != text:
            xml.write_text(new, encoding="utf-8")
            changed += 1
            print(f"rewrote hrefs: {xml.name}")
    return changed


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: rewrite_policy_hrefs.py <fix-dir>")
    n = rewrite(Path(sys.argv[1]))
    print(f"files updated: {n}")
