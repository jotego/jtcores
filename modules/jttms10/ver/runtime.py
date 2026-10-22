"""Transport validated YAML cases to the runtime-driven SystemVerilog bench."""

from vectors import opcode_at


def runtime_case(case):
    """Serialize controls and architectural checkpoints without deriving results."""
    flag_bits = {"N": 31, "C": 30, "Z": 29, "V": 28}
    header = (
        f"{case['entry']:08x} {len(case['checks'])} "
        f"{int(bool(case.get('expect_fault')))} {case.get('fault_ir', 0):04x} "
        f"{int(bool(case.get('pause_on_ack')))} "
        f"{int('pause_ack_addr' in case)} {case.get('pause_ack_addr', 0):08x} "
        f"{int('pause_ack_write' in case)} {int(bool(case.get('pause_ack_write')))} "
        f"{case.get('expected_requests', -1)} "
        f"{case.get('pixel_size', 16):04x} {case.get('convdp', 0x14):04x} "
        f"{case.get('convsp', 0x14):04x} {case.get('control', 0):04x} "
        f"{case.get('pmask', 0):04x}\n"
    )
    checkpoints = []
    for check in case["checks"]:
        flag_mask = 0
        flag_value = 0
        for flag, value in check.get("flags", {}).items():
            bit = flag_bits[flag]
            flag_mask |= 1 << bit
            flag_value |= value << bit
        registers = []
        for name, value in check.get("regs", {}).items():
            index = int(name[1:])
            physical = 15 if index == 15 else (16 if name[0] == "B" else 0) + index
            registers.extend((str(physical), f"{value:08x}"))
        memory = [item for field in check.get("mem", []) for item in
                  (f"{field['addr']:08x}", str(field["size"]),
                   f"{field['value']:08x}")]
        checkpoints.append(
            f"{opcode_at(case, check['after']):04x} {check['pc']:08x} "
            f"{int('st' in check)} {check.get('st', 0):08x} "
            f"{flag_mask:08x} {flag_value:08x} {int('wvp' in check)} "
            f"{check.get('wvp', 0)} {len(registers) // 2} {len(memory) // 3} "
            + " ".join(registers + memory) + "\n"
        )
    return header + "".join(checkpoints)
