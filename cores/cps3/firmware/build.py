#!/usr/bin/env python3
import argparse
import binascii
import os
import shutil
import subprocess
import zipfile
from pathlib import Path


BIOS_SIZE = 0x80000
KEY1 = 0xB5FE053E
KEY2 = 0xFC03925A
ROOT = Path(__file__).resolve().parent
DEFAULT_HEADER_BANKS = "00 08 00 08 00 08 00 08"
SFIII_HEADER_BANKS = "00 88 00 88 01 88 02 88"

SYS_CHECK_EXTRA_ROM_PARTS = """        <!-- simm1.0 - starts at 0x80000 - length 0x800000 (23 bits) -->
        <interleave output="32">
            <part name="sfiii-simm1.1" crc="57920546" map="0001"/>
            <part name="sfiii-simm1.0" crc="cfc9e45a" map="0010"/>
            <part name="sfiii-simm1.3" crc="ea4ca054" map="0100"/>
            <part name="sfiii-simm1.2" crc="0d8f2680" map="1000"/>
        </interleave>
        <!-- JTFRAME_BA1_START -->
        <!-- simm2.0 - starts at 0x880000 -->
        <!-- simm2.1 - starts at 0x880000 -->
        <!-- simm2.2 - starts at 0x880000 -->
        <!-- simm2.3 - starts at 0x880000 -->
        <!-- simm3.0 - starts at 0x880000 - length 0x1000000 (24 bits) -->
        <interleave output="16">
            <part name="sfiii-simm3.1" crc="5c356f2f" map="01"/>
            <part name="sfiii-simm3.0" crc="080b3bd3" map="10"/>
        </interleave>
        <interleave output="16">
            <part name="sfiii-simm3.3" crc="09de3ead" map="01"/>
            <part name="sfiii-simm3.2" crc="f9c97a45" map="10"/>
        </interleave>
        <interleave output="16">
            <part name="sfiii-simm3.5" crc="47a03a3a" map="01"/>
            <part name="sfiii-simm3.4" crc="7dd7e1f3" map="10"/>
        </interleave>
        <interleave output="16">
            <part name="sfiii-simm3.7" crc="7f44395c" map="01"/>
            <part name="sfiii-simm3.6" crc="e9eb7a26" map="10"/>
        </interleave>
        <!-- JTFRAME_BA2_START -->
        <!-- simm4.0 - starts at 0x1880000 - length 0x1000000 (24 bits) -->
        <interleave output="16">
            <part name="sfiii-simm4.1" crc="6e2c4c94" map="01"/>
            <part name="sfiii-simm4.0" crc="9ac080fc" map="10"/>
        </interleave>
        <interleave output="16">
            <part name="sfiii-simm4.3" crc="9f3873b8" map="01"/>
            <part name="sfiii-simm4.2" crc="8afc22d4" map="10"/>
        </interleave>
        <interleave output="16">
            <part name="sfiii-simm4.5" crc="e5ea2547" map="01"/>
            <part name="sfiii-simm4.4" crc="166b3c97" map="10"/>
        </interleave>
        <interleave output="16">
            <part name="sfiii-simm4.7" crc="362c01b7" map="01"/>
            <part name="sfiii-simm4.6" crc="e85b9fdd" map="10"/>
        </interleave>
        <!-- JTFRAME_BA3_START -->
        <!-- simm5.0 - starts at 0x2880000 - length 0x400000 (22 bits) -->
        <interleave output="16">
            <part name="sfiii-simm5.1" crc="c6f1c066" map="01"/>
            <part name="sfiii-simm5.0" crc="9bc108b2" map="10"/>
        </interleave>
        <!-- simm6.0 - starts at 0x2C80000 -->
        <!-- simm6.1 - starts at 0x2C80000 -->
        <!-- simm6.2 - starts at 0x2C80000 -->
        <!-- simm6.3 - starts at 0x2C80000 -->
        <!-- simm6.4 - starts at 0x2C80000 -->
        <!-- simm6.5 - starts at 0x2C80000 -->
        <!-- simm6.6 - starts at 0x2C80000 -->
        <!-- simm6.7 - starts at 0x2C80000 -->
        <!-- Total 0x2C80000 bytes - 45568 kBytes -->
"""

TARGETS = {
    "bios_test": {
        "source": "bios_test.s",
        "stem": "bios_test",
        "setname": "cps3_bios_test",
        "name": "CPS3 BIOS TEST",
        "zip": "cps3_bios_test.zip",
        "mra": "cps3_bios_test.mra",
        "part": "bios_test.29f400.u2",
        "comment": "Minimal CPS3 BIOS test firmware",
        "rom_comment": "BIOS test",
        "header_banks": DEFAULT_HEADER_BANKS,
        "joystick": "0",
    },
    "syscheck": {
        "source": "syscheck.s",
        "stem": "syscheck",
        "setname": "cps3_syscheck",
        "name": "CPS3 SYSCHECK",
        "zip": "cps3_syscheck.zip",
        "mra_zip": "sfiii.zip|cps3_syscheck.zip",
        "mra": "cps3_syscheck.mra",
        "part": "syscheck.29f400.u2",
        "comment": "CPS3 system-check diagnostic firmware",
        "rom_comment": "CPS3 SYSCHECK",
        "extra_rom_parts": SYS_CHECK_EXTRA_ROM_PARTS,
        "header_banks": SFIII_HEADER_BANKS,
        "joystick": "8",
    },
}

def rotate_left16(value: int, count: int) -> int:
    return ((value << count) | (value >> (16 - count))) & 0xFFFF


def rotxor(value: int, xor_value: int) -> int:
    result = (value + rotate_left16(value, 2)) & 0xFFFF
    result = rotate_left16(result, 4) ^ (result & (value ^ xor_value))
    return result & 0xFFFF


def cps3_mask(address: int, key1: int, key2: int) -> int:
    address ^= key1
    value = (address & 0xFFFF) ^ 0xFFFF
    value = rotxor(value, key2 & 0xFFFF)
    value ^= ((address >> 16) & 0xFFFF) ^ 0xFFFF
    value = rotxor(value & 0xFFFF, (key2 >> 16) & 0xFFFF)
    value ^= (address & 0xFFFF) ^ (key2 & 0xFFFF)
    value &= 0xFFFF
    return (value << 16) | value


def assemble(source: Path, obj: Path, binary: Path, as_bin: str, objcopy_bin: str) -> None:
    subprocess.run(
        [as_bin, "--big", "--isa=sh2a", "-o", str(obj), str(source)],
        check=True,
    )
    subprocess.run(
        [objcopy_bin, "-O", "binary", "-j", ".text", str(obj), str(binary)],
        check=True,
    )


def make_encrypted_bios(plain: bytes, key1: int, key2: int) -> bytes:
    if len(plain) > BIOS_SIZE:
        raise SystemExit(f"plaintext BIOS is too large: {len(plain):#x} > {BIOS_SIZE:#x}")
    plain = plain.ljust(BIOS_SIZE, b"\xff")
    out = bytearray(BIOS_SIZE)
    for address in range(0, BIOS_SIZE, 4):
        decrypted = int.from_bytes(plain[address:address + 4], "big")
        encrypted_raw = decrypted ^ cps3_mask(address, key1, key2)
        out[address:address + 4] = encrypted_raw.to_bytes(4, "big")
    return bytes(out)


def write_zip(path: Path, payload_name: str, payload: bytes) -> None:
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr(payload_name, payload)


def copy_to_mister(zip_path: Path, mra_path: Path) -> None:
    passwd = os.environ.get("MISTERPASSWD")
    if not passwd:
        return

    if shutil.which("sshpass") is None:
        raise SystemExit("MISTERPASSWD is set but sshpass was not found")

    env = os.environ.copy()
    env["SSHPASS"] = passwd
    scp_base = ["sshpass", "-e", "scp"]

    copies = [
        (zip_path, "root@mister.home:/media/fat/games/mame/"),
        (mra_path, "root@mister.home:/media/fat/_JTBIN/"),
    ]

    rbf_path = ROOT.parents[2] / "release/mister/jtcps3.rbf"
    if rbf_path.exists():
        copies.append((rbf_path, "root@mister.home:/media/fat/_JTBIN/cores/"))

    for src, dst in copies:
        print(f"copy:      {src} -> {dst}")
        subprocess.run([*scp_base, str(src), dst], check=True, env=env)


def write_mra(path: Path, target: dict[str, str], crc: int) -> None:
    mra_zip = target.get("mra_zip", target["zip"])
    extra_rom_parts = target.get("extra_rom_parts", "")
    header_banks = target.get("header_banks", DEFAULT_HEADER_BANKS)
    joystick = target.get("joystick", "0")
    path.write_text(
        f"""<!-- {target["comment"]}. Generated by firmware/build.py. -->
<misterromdescription>
    <about author="jotego" webpage="https://patreon.com/jotego" twitter="@topapate" source="https://jotego/jtcores"/>
    <rotation>horizontal</rotation>
    <name>{target["name"]}</name>
    <setname>{target["setname"]}</setname>
    <year>2026</year>
    <manufacturer>Jotego</manufacturer>
    <players>1</players>
    <rbf>jtcps3</rbf>
    <joystick>{joystick}</joystick>
    <region>World</region>
    <rom index="0" zip="{mra_zip}">
        <part>
            {header_banks}
            FF FF 00 00 00 00 00 00
            B5 FE 05 3E FC 03 92 5A
            00 00 00 00 00 00 00 00
        </part>
        <!-- {target["rom_comment"]} - starts at 0x0 - length 0x80000 (19 bits) -->
        <part name="{target["part"]}" crc="{crc:08x}"/>
{extra_rom_parts}    </rom>
    <rom index="1">
        <part>00 80</part>
    </rom>
</misterromdescription>
""",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the encrypted CPS3 BIOS test firmware.")
    parser.add_argument("--target", choices=sorted(TARGETS), default="bios_test")
    parser.add_argument("--as", dest="as_bin", default="sh-elf-as")
    parser.add_argument("--objcopy", dest="objcopy_bin", default="sh-elf-objcopy")
    parser.add_argument("--out-dir", type=Path, default=ROOT / "build")
    args = parser.parse_args()

    if shutil.which(args.as_bin) is None:
        raise SystemExit(f"{args.as_bin} not found")
    if shutil.which(args.objcopy_bin) is None:
        raise SystemExit(f"{args.objcopy_bin} not found")

    target = TARGETS[args.target]
    args.out_dir.mkdir(parents=True, exist_ok=True)
    obj = args.out_dir / f"{target['stem']}.o"
    raw = args.out_dir / f"{target['stem']}_raw.bin"
    plain = args.out_dir / f"{target['stem']}_plain.bin"
    encrypted = args.out_dir / target["part"]
    mra = args.out_dir / target["mra"]
    zip_path = args.out_dir / target["zip"]

    assemble(ROOT / target["source"], obj, raw, args.as_bin, args.objcopy_bin)
    plain_data = raw.read_bytes().ljust(BIOS_SIZE, b"\xff")
    plain.write_bytes(plain_data)
    encrypted_data = make_encrypted_bios(plain_data, KEY1, KEY2)
    encrypted.write_bytes(encrypted_data)
    write_zip(zip_path, encrypted.name, encrypted_data)
    crc = binascii.crc32(encrypted_data) & 0xFFFFFFFF
    write_mra(mra, target, crc)
    write_mra(ROOT / target["mra"], target, crc)

    print(f"plain:     {plain}")
    print(f"encrypted: {encrypted} crc={crc:08x}")
    print(f"zip:       {zip_path}")
    print(f"mra:       {mra}")
    copy_to_mister(zip_path, mra)


if __name__ == "__main__":
    main()
