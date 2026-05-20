"""Sphinx configuration for the Haxe/HashLink Quadrants documentation."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HAXELIB_JSON = ROOT / "bindings" / "hashlink" / "haxelib.json"

project = "Quadrants"
copyright = "2025 Genesis AI Inc"
author = "Quadrants developers"

try:
    release = json.loads(HAXELIB_JSON.read_text(encoding="utf-8")).get("version", "0.0.0")
except OSError:
    release = "0.0.0"
version = release

extensions = [
    "myst_parser",
]

myst_enable_extensions = ["colon_fence", "dollarmath", "amsmath"]
myst_heading_anchors = 4

exclude_patterns = ["build", "Thumbs.db", ".DS_Store"]

html_theme = "alabaster"
html_title = "Quadrants Haxe/HashLink documentation"
