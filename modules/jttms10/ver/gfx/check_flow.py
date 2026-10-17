#!/usr/bin/env python3
"""Audit reachable graphics microcode and its two-entry return stack."""

import argparse
from collections import deque
from pathlib import Path
import re

import yaml

from check_targets import load_schema


def audit(schema, engine):
    config = yaml.safe_load(schema.read_text())["config"]
    entry_len = config["entry_len"]
    limit = config["entries"] * entry_len
    items, constants = load_schema(schema)
    words, entries = {}, {}
    for item in items:
        if not item.get("name") or item.get("start", -1) < 0:
            continue
        start = item["start"] * entry_len
        name = item["name"].upper()
        entries[name] = start
        for offset, line in enumerate(item.get("seq", [])):
            words[start + offset] = (name, offset, line)

    names = set(re.findall(r"\buaddr\s*<=\s*(\w+)_SEQA\b",
                           engine.read_text()))
    if not names:
        raise SystemExit("graphics flow: no engine entry points found")
    unknown = names - entries.keys()
    if unknown:
        raise SystemExit(f"graphics flow: unknown entries {sorted(unknown)}")
    queue = deque((entries[name], ()) for name in sorted(names))
    parents = {state: None for state in queue}
    seen, maximum = set(), 0

    def fail(message, state):
        trail = []
        while state is not None:
            pc, stack = state
            word = words.get(pc)
            label = f"{word[0]}+{word[1]}" if word else f"{pc:#x}"
            trail.append(f"{label}[{len(stack)}]")
            state = parents[state]
        raise SystemExit(f"graphics flow: {message}\n" +
                         " -> ".join(reversed(trail)))

    while queue:
        state = queue.popleft()
        if state in seen:
            continue
        seen.add(state)
        if len(seen) > 1_000_000:
            fail("state limit exceeded", state)
        pc, stack = state
        maximum = max(maximum, len(stack))
        if pc not in words or not words[pc][2].strip():
            fail("reachable empty microcode word", state)
        line = words[pc][2]
        tokens = line.replace(",", " ").split()
        conditional = any(token.lower().endswith("_gcond") for token in tokens)
        flows = [token.lower() for token in tokens
                 if token.lower().endswith("_gflow")]
        if len(flows) > 1:
            fail("multiple flow controls", state)
        flow = flows[0] if flows else "next_gflow"
        following = ((pc + 1) % limit, stack)
        successors = []
        if flow == "end_gflow":
            pass
        elif flow == "ret_gflow":
            if not stack:
                fail("return stack underflow", state)
            successors.append((stack[-1], stack[:-1]))
        elif flow in ("jump_gflow", "call_gflow"):
            labels = re.findall(r"\$\{(TARGET_\w+)\}", line)
            if len(labels) != 1 or labels[0] not in constants:
                fail("branch must use one defined TARGET constant", state)
            target = 0
            for bit in constants[labels[0]].split():
                match = re.fullmatch(r"t(\d+)", bit)
                if not match:
                    fail("invalid target bit", state)
                target |= 1 << int(match.group(1))
            if flow == "call_gflow":
                if len(stack) >= 2:
                    fail("return stack overflow", state)
                successors.append((target, stack + (following[0],)))
            else:
                successors.append((target, stack))
            if conditional:
                successors.append(following)
        elif flow in ("next_gflow", "check_gflow"):
            successors.append(following)
        else:
            fail(f"unknown flow control {flow}", state)
        for successor in successors:
            if successor not in parents:
                parents[successor] = state
                queue.append(successor)

    print(f"graphics flow PASS: {len(seen)} states, return depth {maximum}/2, "
          f"{len(names)} entries")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("schema", type=Path)
    parser.add_argument("--engine", type=Path)
    args = parser.parse_args()
    engine = args.engine or args.schema.parent.parent / "hdl/jttms10_gfx.v"
    audit(args.schema, engine)


if __name__ == "__main__":
    main()
