#!/usr/bin/env python3
"""Generate fixed, input-independent observable YC vectors for test.sv.

The chroma oracle uses the documented integer YUV coefficients, arithmetic
right shifts, baseline signed 256-entry sine samples and explicit sample
latencies. It does not read candidate RTL state or candidate output samples.
"""
from pathlib import Path
import re
import sys


N = 261
PHASE_INC = 0x1000000000
BURST_FIRST, BURST_LAST = 4, 20
MASK40 = (1 << 40) - 1
MASK21 = (1 << 21) - 1


def s(value, width):
    value &= (1 << width) - 1
    return value - (1 << width) if value & (1 << (width - 1)) else value


def lut_values():
    test = Path(__file__).with_name("test.sv").read_text()
    section = test.split("expected_lut [0:255] = '{", 1)[1].split("};", 1)[0]
    words = re.findall(r"11'h([0-9A-Fa-f]{3})", section)
    if len(words) != 256:
        raise RuntimeError(f"expected 256 independent sine words, got {len(words)}")
    return [s(int(word, 16), 11) for word in words]


def trace():
    rows = []

    def put(h=0, v=0, c=0, de=0, rgb=0):
        rows.append((h, v, c, de, rgb))

    put(1, 1, 1, 1, 0xFFFFFF)
    for _ in range(7):
        put(rgb=0)
    for _ in range(3):
        put(rgb=0)
    put(1, rgb=0)
    put(1, rgb=0)
    put(rgb=0)
    for _ in range(36):
        put(rgb=0)
    for _ in range(20):
        put(de=0, rgb=0xFF0000)
    for rgb in (0xFF0000, 0x00FF00, 0x0000FF, 0xFFFFFF, 0x000000, 0x808080):
        for _ in range(20):
            put(de=1, rgb=rgb)
    put(1, rgb=0)
    put(1, rgb=0)
    put(rgb=0)
    for _ in range(26):
        put(rgb=0)
    for _ in range(20):
        put(de=1, rgb=0xFF0000)
    for _ in range(20):
        put(de=1, rgb=0x0000FF)
    put(1, rgb=0)
    put(1, rgb=0)
    if len(rows) != N:
        raise RuntimeError(f"stimulus length changed: {len(rows)} != {N}")
    return rows


class YCModel:
    def __init__(self, pal, sine):
        self.pal = pal
        self.sine = sine
        self.acc = self.lut = 0
        self.carrier_sin = self.carrier_cos = self.carrier_burst = 0
        self.flip = self.line_count = False
        self.cburst = 0
        self.r1 = self.r2 = self.b1 = self.b2 = 0
        self.yr = self.yg = self.yb = self.y = 0
        self.u0 = self.v0 = self.u1 = self.v1 = 0
        self.u2 = self.v2 = self.u3 = self.v3 = 0
        self.burst2 = self.chroma2 = self.burst3 = self.chroma3 = False
        self.c4 = 0
        self.luma = [0] * 5
        self.de = [0] * 7

    def step(self, hsync, de, rgb):
        red, green, blue = (rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255
        old = self.__dict__.copy()
        old_luma = old["luma"][:]
        old_de = old["de"][:]

        # The output registers consume the completed chroma/luma sample and
        # DE flag that were present before this clock edge.
        c_out = old["c4"] & 255
        cvbs_y = ((old_luma[4] >> 1) + (old["c4"] & 255) // 2) & 255

        # YUV sample math: Y=(306R+601G+117B)>>10, U=504(B-Y), V=898(R-Y).
        y_byte = (old["y"] >> 10) & 255
        u0 = s(old["b2"] - y_byte, 21)
        v0 = s(old["r2"] - y_byte, 21)
        u1 = s(old["u0"] * 504, 21)
        v1 = s(old["v0"] * 898, 21)

        # The carrier phase accumulator advances independently from the
        # registered sine/cosine samples used by the multipliers.
        carrier_burst = self.sine[(old["lut"] + (160 if old["flip"] else 96)) & 255] if self.pal else self.sine[(old["lut"] + 128) & 255]
        carrier_sin = self.sine[old["lut"]]
        carrier_cos = self.sine[(old["lut"] + 64) & 255]
        lut = (old["acc"] >> 32) & 255
        acc = (old["acc"] + PHASE_INC) & MASK40

        if hsync:
            cburst = 0
            u2 = v2 = 0
            burst2 = chroma2 = False
            c4 = 128
            flip = not old["flip"] if old["line_count"] else old["flip"]
            line_count = (not old["line_count"]) if old["line_count"] else old["line_count"]
            u3, v3 = old["u3"], old["v3"]
            burst3, chroma3 = old["burst2"], old["chroma2"]
        else:
            burst_now = BURST_FIRST <= old["cburst"] <= BURST_LAST
            if burst_now:
                u2 = s(old["carrier_burst"] << 5, 21)
                v2 = 0
                burst2, chroma2 = True, False
            else:
                u2 = s((old["u1"] >> 10) * old["carrier_sin"], 21)
                v2 = s((old["v1"] >> 10) * old["carrier_cos"], 21)
                burst2, chroma2 = False, bool(old_de[3])

            # Scale the preceding stage-2 sample using its registered mode.
            if old["burst2"]:
                shifts = (8, 11, 12, 14) if self.pal else (8, 11, 12, 13)
            else:
                shifts = (9, 10, 14)
            u3 = s(sum(s(old["u2"] >> sh, 21) for sh in shifts), 21)
            v3 = s(sum(s(old["v2"] >> sh, 21) for sh in (9, 10, 14)), 21)

            if old["burst3"] or old["chroma3"]:
                signed_v = -old["v3"] if self.pal and old["flip"] else old["v3"]
                c4 = s(128 + old["u3"] + signed_v, 21)
                line_count = True if self.pal else old["line_count"]
            else:
                c4 = 128
                line_count = old["line_count"]
            flip = old["flip"]
            cburst = old["cburst"] + 1 if old["cburst"] <= BURST_LAST else old["cburst"]
            burst3, chroma3 = old["burst2"], old["chroma2"]

        # Luma datapath and delayed DE are independent of chroma generation.
        y = s(old["yr"] + old["yg"] + old["yb"], 21)
        yr, yg, yb = red * 306, green * 601, blue * 117
        luma = [y_byte, *old_luma[:4]]
        de_pipe = [de, *old_de[:6]]

        self.__dict__.update({
            "acc": acc, "lut": lut,
            "carrier_sin": carrier_sin, "carrier_cos": carrier_cos, "carrier_burst": carrier_burst,
            "flip": flip, "line_count": line_count, "cburst": cburst,
            "r1": red, "r2": old["r1"], "b1": blue, "b2": old["b1"],
            "yr": yr, "yg": yg, "yb": yb, "y": y,
            "u0": u0, "v0": v0, "u1": u1, "v1": v1,
            "u2": u2, "v2": v2, "u3": u3, "v3": v3,
            "burst2": burst2, "chroma2": chroma2, "burst3": burst3, "chroma3": chroma3,
            "c4": c4, "luma": luma, "de": de_pipe,
        })
        return c_out, cvbs_y


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "obj_dir")
    out.mkdir(parents=True, exist_ok=True)
    sine = lut_values()
    pal, ntsc = YCModel(True, sine), YCModel(False, sine)
    rows = trace()
    with (out / "yc_trace.hex").open("w") as trace_file, (out / "yc_expected.hex").open("w") as expected_file:
        for h, v, c, de, rgb in rows:
            trace_file.write(f"{(h << 27) | (v << 26) | (c << 25) | (de << 24) | rgb:07x}\n")
            pc, py = pal.step(h, de, rgb)
            nc, ny = ntsc.step(h, de, rgb)
            expected_file.write(f"{(pc << 24) | (nc << 16) | (py << 8) | ny:08x}\n")


if __name__ == "__main__":
    main()
