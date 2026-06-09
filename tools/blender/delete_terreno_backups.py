#!/usr/bin/env python3
"""Remove Terreno_Finca backups that could restore broken terrain."""
from __future__ import annotations

import glob
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

PATTERNS = [
    os.path.join(ROOT, "assets", "models", "environment", "Terreno_Finca.blend1"),
    os.path.join(ROOT, "assets", "models", "environment", "Terreno_Finca_BACKUP*"),
    os.path.join(ROOT, "assets", "models", "environment", "*BACKUP*Terreno*"),
    os.path.join(ROOT, ".godot", "imported", "Terreno_Finca_BACKUP*"),
    os.path.join(ROOT, ".godot", "editor", "Terreno_Finca_BACKUP*"),
    "/tmp/Terreno_Finca_pre_sculpt.blend",
    "/tmp/Terreno_Finca_*.blend",
]


def main() -> int:
    removed = []
    for pattern in PATTERNS:
        for path in glob.glob(pattern):
            if not os.path.isfile(path):
                continue
            os.remove(path)
            removed.append(path)
    print(f"removed {len(removed)} backup files")
    for path in removed:
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
