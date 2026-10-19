#!/usr/bin/env python3
"""Check literal graphics-ROM branch bits against named entry addresses."""

import argparse
import re
from pathlib import Path

import yaml


def load_schema(path, ancestors=()):
    path = path.resolve()
    if path in ancestors:
        raise SystemExit(f"graphics ROM include cycle: {path}")
    desc = yaml.safe_load(path.read_text()) or {}
    items = list(desc.get("ucode", []))
    constants = dict(desc.get("constants", {}))
    for name in desc.get("include", []):
        child_items, child_constants = load_schema(path.parent / name, ancestors + (path,))
        items.extend(child_items)
        for key, value in child_constants.items():
            if key in constants and constants[key] != value:
                raise SystemExit(f"graphics ROM duplicate constant {key}")
            constants[key] = value
    return items, constants


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("schema", type=Path)
    parser.add_argument("parameters", type=Path)
    parser.add_argument("image", type=Path)
    args = parser.parse_args()

    desc = yaml.safe_load(args.schema.read_text())
    config = desc["config"]
    entry_len = config["entry_len"]
    entries = config["entries"]
    if (entries, entry_len) != (256, 16):
        raise SystemExit("graphics ROM must contain 256 entries of 16 words")

    words = args.image.read_text().splitlines()
    if len(words) != entries * entry_len or not words:
        raise SystemExit("graphics ROM image depth differs from its schema")
    width = len(words[0])
    if width > 64 or any(len(word) != width or set(word) - {"0", "1"}
                         for word in words):
        raise SystemExit("graphics ROM must contain uniform binary words of at most 64 bits")

    items, constants = load_schema(args.schema)
    named = {}
    starts = {}
    for item in items:
        if not item.get("name") or item.get("start", -1) < 0:
            continue
        label = item["name"].upper()
        if label in named:
            raise SystemExit(f"graphics ROM duplicate entry {label}")
        start = item["start"]
        if start >= entries or len(item.get("seq", [])) > entry_len:
            raise SystemExit(f"graphics ROM entry {label} exceeds its 16-word slot")
        if start in starts:
            raise SystemExit(f"graphics ROM entry {label} overlaps {starts[start]} "
                             f"at {start}")
        starts[start] = label
        named[label] = item["start"] * entry_len
    header = args.parameters.read_text()
    for item in items:
        for step in item.get("seq", []):
            if (item.get("name") not in ("gschema0", "gschema1") and
                re.search(r"(?<![A-Za-z0-9_])t(?:1[01]|[0-9])(?![A-Za-z0-9_])", step)):
                raise SystemExit(f"{item.get('name', 'unnamed')}: use a TARGET_* constant, "
                                 "not raw target bits, in a microstep")
            for label in re.findall(r"\$\{(TARGET_[A-Za-z0-9_]+)\}", step):
                if label not in constants:
                    raise SystemExit(f"{item.get('name', 'unnamed')}: undefined {label}")
    checked = 0
    for key, tokens in constants.items():
        if not key.startswith("TARGET_"):
            continue
        label = key[len("TARGET_"):]
        if label not in named:
            raise SystemExit(f"{key} names no graphics ROM entry")
        if not isinstance(tokens, str):
            raise SystemExit(f"{key} must be a space-separated literal bitset")
        bits = tokens.split()
        if len(bits) != len(set(bits)):
            raise SystemExit(f"{key} repeats a target bit")
        target = 0
        for bit in bits:
            match = re.fullmatch(r"t(\d+)", bit)
            if not match or not 4 <= int(match.group(1)) <= 11:
                raise SystemExit(f"{key} contains invalid target bit {bit!r}")
            target |= 1 << int(match.group(1))
        match = re.search(rf"\b{re.escape(label)}_SEQA\s*=\s*\d+'h([0-9a-fA-F]+)", header)
        if not match:
            raise SystemExit(f"generated header lacks {label}_SEQA")
        generated = int(match.group(1), 16)
        if target != generated or target != named[label]:
            raise SystemExit(f"{key}: literal {target:#x}, generated {generated:#x}, "
                             f"schema {named[label]:#x}")
        checked += 1
    if not checked:
        raise SystemExit("graphics ROM has no checked TARGET_* constants")
    print(f"graphics ROM PASS: {len(words)} x {width}, {checked} branch targets")


if __name__ == "__main__":
    main()
