#!/usr/bin/env python3
"""Reject conflicting CPU flow controls before JTFRAME encodes their bits."""

import argparse
from pathlib import Path

import yaml


def source_files(path, seen=None):
    path = path.resolve()
    seen = set() if seen is None else seen
    if path in seen:
        return
    seen.add(path)
    data = yaml.safe_load(path.read_text()) or {}
    for include in data.get("include", []):
        yield from source_files(path.parent / include, seen)
    for item in data.get("ucode", []):
        for offset, line in enumerate(item.get("seq", [])):
            yield path, item.get("name", "<unnamed>"), offset, line


def audit(path):
    errors = []
    for source, name, offset, line in source_files(path):
        if not isinstance(line, str):
            continue
        flows = [token.strip().lower() for token in line.replace(",", " ").split()
                 if token.strip().lower().endswith("_flow")]
        if len(flows) > 1:
            errors.append(f"{source}:{name}+{offset}: conflicting flow controls {flows}")
    if errors:
        raise ValueError("\n".join(errors))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("schema", type=Path)
    args = parser.parse_args()
    try:
        audit(args.schema)
    except (OSError, ValueError, yaml.YAMLError) as exc:
        parser.error(str(exc))
    print(f"CPU flow PASS: {args.schema}")


if __name__ == "__main__":
    main()
