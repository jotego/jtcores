#!/usr/bin/env python3
"""Validate and compare HD6309 long-batch result windows."""

import argparse
import struct
import sys
from pathlib import Path

MAGIC = 0x544D544A
VERSION = 1
WORD_COUNT = 96
INSTRUCTIONS = (0x0110, 0x0112, 0x0114, 0x0117, 0x011A, 0x011E,
                0x0125, 0x0121, 0x0129, 0x012C, 0x0130, 0x0133,
                0x0136, 0x013A, 0x013D, 0x013F, 0x0141, 0x0143,
                0x0145, 0x0149, 0x014D, 0x014F, 0x0151, 0x0153,
                0x0155)
EMULATION_CYCLES = (3, 6, 4, 3, 28, 25, 4, 34, 6, 7, 6, 7, 7,
                    6, 5, 5, 5, 4, 6, 9, 5, 8, 5, 8, 3)
NATIVE_CYCLES = (2, 4, 4, 3, 28, 25, 4, 34, 6, 6, 6, 7, 7,
                 6, 5, 5, 5, 4, 6, 9, 5, 8, 5, 8, 3)


def load_result(path: Path, requested_mode: str, requested_count: int) -> tuple[int, ...]:
    data = path.read_bytes()
    if len(data) != WORD_COUNT * 4:
        raise ValueError(f"{path}: expected {WORD_COUNT * 4} bytes, got {len(data)}")
    words = struct.unpack(f"<{WORD_COUNT}I", data)
    if words[0] != MAGIC or words[1] != VERSION or words[3] != WORD_COUNT:
        raise ValueError(f"{path}: invalid JTMT header")
    if words[2] & 1 or not words[2] & 2:
        raise ValueError(f"{path}: incomplete result status 0x{words[2]:08x}")
    expected_mode = 1 if requested_mode == "native" else 0
    mode, target, completed, total_cycles = words[4:8]
    if mode != expected_mode:
        raise ValueError(f"{path}: mode {mode}, expected {expected_mode}")
    if target != requested_count or completed != target:
        raise ValueError(f"{path}: target/completed is {target}/{completed}, expected {requested_count}")

    per_instruction = NATIVE_CYCLES if mode else EMULATION_CYCLES
    loop_count = target // len(INSTRUCTIONS)
    expected_total = loop_count * sum(per_instruction)
    if total_cycles != expected_total:
        raise ValueError(f"{path}: total cycles {total_cycles}, expected {expected_total} from published timing")
    cycle_sum = 0
    count_sum = 0
    for slot, (pc_expected, cycles_expected) in enumerate(zip(INSTRUCTIONS, per_instruction)):
        pc, count, cycles = words[8 + slot * 3 : 11 + slot * 3]
        if pc != pc_expected:
            raise ValueError(f"{path}: slot {slot} PC 0x{pc:04x}, expected 0x{pc_expected:04x}")
        if count != loop_count:
            raise ValueError(f"{path}: PC 0x{pc:04x} count {count}, expected {loop_count}")
        expected_cycles = count * cycles_expected
        if cycles != expected_cycles:
            raise ValueError(f"{path}: PC 0x{pc:04x} E cycles {cycles}, expected {expected_cycles}")
        count_sum += count
        cycle_sum += cycles
    if count_sum != completed or cycle_sum != total_cycles:
        raise ValueError(f"{path}: per-PC sums do not match completed instruction/cycle totals")

    if words[83] != 0:
        raise ValueError(f"{path}: TFM RAM snapshot 0x{words[83]:02x}, expected 00")
    if words[92] != 0x05:
        raise ValueError(f"{path}: AIM result 0x{words[92]:02x}, expected 05")
    if words[93] != 0xAF:
        raise ValueError(f"{path}: OIM result 0x{words[93]:02x}, expected AF")
    expected_eim = 0xAA if loop_count & 1 else 0xA5
    if words[94] != expected_eim:
        raise ValueError(f"{path}: EIM result 0x{words[94]:02x}, expected {expected_eim:02x}")
    if words[95] != 0xA5:
        raise ValueError(f"{path}: TIM result 0x{words[95]:02x}, expected A5")
    if (words[90] >> 16) != 0:
        raise ValueError(f"{path}: final W is 0x{words[90] >> 16:04x}, expected 0000")
    if ((words[91] >> 16) & 0xFF) != mode:
        raise ValueError(f"{path}: MD snapshot {((words[91] >> 16) & 0xff):02x}, expected {mode:02x}")
    return words


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fpga", type=Path, help="MiSTer capture binary")
    parser.add_argument("verilator", type=Path, help="Verilator capture binary")
    parser.add_argument("--mode", choices=("emulation", "native"), required=True)
    parser.add_argument("--instructions", type=int, required=True)
    args = parser.parse_args()
    try:
        fpga = load_result(args.fpga, args.mode, args.instructions)
        verilator = load_result(args.verilator, args.mode, args.instructions)
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 2

    mismatches = [(i, x, y) for i, (x, y) in enumerate(zip(fpga, verilator)) if x != y]
    if mismatches:
        for index, x, y in mismatches:
            print(f"word {index}: FPGA=0x{x:08x} Verilator=0x{y:08x}")
        return 1
    print(f"MATCH mode={args.mode} instructions={args.instructions} E_cycles={fpga[7]} words={WORD_COUNT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
