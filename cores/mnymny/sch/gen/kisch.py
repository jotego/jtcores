#!/usr/bin/env python3
"""Minimal KiCad 8 schematic emitter for the mnymny board.
Places symbols from the jtkicad libs / local lib, wires power to pins, and
attaches net-name labels exactly on pin endpoints (name-based connectivity).
Pin transform (verified against cores/kunio): at rot 0, pin_abs=(X+px, Y-py);
general = rotate (px,-py) by the placement angle, then translate."""
import re, math, uuid, sys

def load(path): return open(path).read()

def extract(text, name):
    pat = f'(symbol "{name}"'
    i = text.find(pat)
    if i < 0: return None
    d = 0; j = i
    while j < len(text):
        if text[j] == '(': d += 1
        elif text[j] == ')':
            d -= 1
            if d == 0: return text[i:j+1]
        j += 1
    return None

def pins_of(sym_block):
    """return {number:(x,y,ang)} across all unit sub-symbols"""
    out = {}
    for m in re.finditer(r'\(pin\s+\w+\s+\w+\s*\(at ([-\d.]+) ([-\d.]+) (\d+)\)[\s\S]*?\(number "([^"]*)"', sym_block):
        out[m.group(4)] = (float(m.group(1)), float(m.group(2)), int(m.group(3)))
    return out

def pin_abs(X, Y, R, px, py):
    a = math.radians(R); y = -py
    dx = px*math.cos(a) - y*math.sin(a)
    dy = px*math.sin(a) + y*math.cos(a)
    return (round(X+dx, 2), round(Y+dy, 2))

def uid(): return str(uuid.uuid4())

LIBS = {
    'jt74':   'modules/jtkicad/lib/jt74.kicad_sym',
    'arcade': 'modules/jtkicad/lib/arcade.kicad_sym',
    'mnymny': 'cores/mnymny/sch/mnymny.kicad_sym',
}
_cache = {p: load(p) for p in LIBS.values()}

def lib_symbol(lib_id):
    lib, name = lib_id.split(':', 1)
    blk = extract(_cache[LIBS[lib]], name)
    if blk is None: raise SystemExit(f"symbol not found: {lib_id}")
    # resolve derived symbols: (extends "PARENT") carries no pins of its own
    m = re.search(r'\(extends "([^"]+)"\)', blk)
    if m:
        parent = m.group(1)
        pblk = extract(_cache[LIBS[lib]], parent)
        if pblk is None: raise SystemExit(f"extends parent not found: {parent}")
        blk = pblk.replace(f'(symbol "{parent}"', f'(symbol "{name}"', 1)
        blk = blk.replace(f'"{parent}_', f'"{name}_')
    # KiCad embeds the PARENT symbol as "lib:name" but keeps the unit
    # sub-symbols as the bare "name_<unit>_<style>" (no lib nick).
    blk = blk.replace(f'(symbol "{name}"', f'(symbol "{lib_id}"', 1)
    return blk

def power_symbol(kind):
    kun = load('cores/kunio/sch/colmix.kicad_sch')
    return extract(kun, f'power:{kind}')

def pins_of_unit(sym_block, unit):
    """pins of one unit sub-symbol: {number:(x,y,ang)}"""
    import re as _re
    base = _re.match(r'\(symbol "([^"]+)"', sym_block).group(1).split(":")[-1]
    out = {}
    for um in _re.finditer(r'\(symbol "'+_re.escape(base)+r'_'+str(unit)+r'_\d+"', sym_block):
        i=um.start(); d=0; j=i
        while j<len(sym_block):
            if sym_block[j]=='(':d+=1
            elif sym_block[j]==')':
                d-=1
                if d==0: sub=sym_block[i:j+1]; break
            j+=1
        for m in _re.finditer(r'\(pin\s+\w+\s+\w+\s*\(at ([-\d.]+) ([-\d.]+) (\d+)\)[\s\S]*?\(number "([^"]*)"', sub):
            out[m.group(4)]=(float(m.group(1)), float(m.group(2)), int(m.group(3)))
    return out

# ---------------- sheet emission helpers (shared by all gen_*.py) ----------------
KUNIO = 'cores/kunio/sch/colmix.kicad_sch'
CLI = '/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli'

def SN(v):
    return round(round(v/1.27)*1.27, 2)

_stock_cache = {}
def stock_symbol(lib_id):
    """Device:* / Connector:* etc. blocks lifted from any existing core sheet."""
    if lib_id in _stock_cache: return _stock_cache[lib_id]
    import glob
    srcs = [KUNIO, 'cores/kunio/sch/io.kicad_sch', 'cores/kunio/sch/sound.kicad_sch',
            'cores/kunio/sch/main.kicad_sch']
    srcs += sorted(glob.glob('cores/wwfss/sch/*.kicad_sch'))
    srcs += sorted(glob.glob('cores/moo/sch/moomesa/*.kicad_sch'))
    srcs += sorted(glob.glob('cores/*/sch/*.kicad_sch')) + sorted(glob.glob('cores/*/sch/*/*.kicad_sch'))
    for src in srcs:
        try: b = extract(load(src), lib_id)
        except FileNotFoundError: continue
        if b:
            _stock_cache[lib_id] = b
            return b
    return None

def get_sym(lib_id):
    if lib_id.startswith('power:'):
        return power_symbol(lib_id.split(':')[1])
    if ':' in lib_id and lib_id.split(':')[0] in LIBS:
        return lib_symbol(lib_id)
    b = stock_symbol(lib_id)
    if b is None: raise SystemExit(f'symbol not found anywhere: {lib_id}')
    return b

class Sheet:
    def __init__(self, title, rev='P82-003/A/M3', paper='A3'):
        self.uuid = uid()
        self.head = ('(kicad_sch\n\t(version 20231120)\n\t(generator "eeschema")\n'
            '\t(generator_version "8.0")\n'
            f'\t(uuid "{self.uuid}")\n\t(paper "{paper}")\n'
            '\t(title_block\n\t\t(title "'+title+'")\n\t\t(date "2026-09-07")\n'
            '\t\t(rev "'+rev+'")\n\t\t(company "JOTEGO")\n'
            '\t\t(comment 1 "Money Money / Jack Rabbit")\n'
            '\t\t(comment 2 "For repair and maintenance")\n\t)\n')
        self.libs = {}          # lib_id -> block
        self.body = []          # symbol instances, wires, labels, junctions
        self.placed = {}        # (ref,unit) -> (X,Y,rot,lib_id)
        self.lanes = set()      # used rail coordinates for uniqueness checks

    def _use(self, lib_id):
        if lib_id not in self.libs:
            self.libs[lib_id] = get_sym(lib_id)

    def prop(self, name, val, x, y, hide=False):
        h = '\n\t\t\t\t(hide yes)' if hide else ''
        return (f'\t\t(property "{name}" "{val}"\n\t\t\t(at {x} {y} 0)\n'
                f'\t\t\t(effects\n\t\t\t\t(font\n\t\t\t\t\t(size 1.27 1.27)\n\t\t\t\t){h}\n\t\t\t)\n\t\t)\n')

    def place(self, lib_id, ref, unit, X, Y, rot=0, value=None, dp=None):
        self._use(lib_id)
        X, Y = SN(X), SN(Y)
        pmap = pins_of(self.libs[lib_id])
        if dp is None:
            dp = 5.08 if lib_id.startswith(('Device:', 'mnymny:Crystal', 'Connector')) else 12
        if value is None:
            value = lib_id.split(':')[1]
        su = uid()
        s = (f'\t(symbol\n\t\t(lib_id "{lib_id}")\n\t\t(at {X} {Y} {rot})\n\t\t(unit {unit})\n'
             '\t\t(exclude_from_sim no)\n\t\t(in_bom yes)\n\t\t(on_board yes)\n\t\t(dnp no)\n'
             f'\t\t(uuid "{su}")\n')
        s += self.prop("Reference", ref, X, Y-dp)
        s += self.prop("Value", value, X, Y+dp)
        s += self.prop("Footprint", "", X, Y, hide=True)
        for num in sorted(pmap):
            s += f'\t\t(pin "{num}"\n\t\t\t(uuid "{uid()}")\n\t\t)\n'
        s += ('\t\t(instances\n\t\t\t(project "mnymny"\n'
              f'\t\t\t\t(path "{self.instpath}"\n\t\t\t\t\t(reference "{ref}")\n\t\t\t\t\t(unit {unit})\n\t\t\t\t)\n\t\t\t)\n\t\t)\n')
        self.body.append(s + '\t)\n')
        self.placed[(ref, unit)] = (X, Y, rot, lib_id)

    instpath = None   # set by save(): "/<root>" or "/<root>/<sheetsym>"

    def pins(self, ref, unit=1):
        X, Y, rot, lib_id = self.placed[(ref, unit)]
        pu = pins_of_unit(self.libs[lib_id] if ':' in lib_id else self.libs[lib_id], unit)
        if not pu:
            pu = pins_of(self.libs[lib_id])
        return {n: pin_abs(X, Y, rot, px, py) for n, (px, py, a) in pu.items()}

    def wire(self, x1, y1, x2, y2):
        self.body.append(f'\t(wire\n\t\t(pts\n\t\t\t(xy {x1} {y1}) (xy {x2} {y2})\n\t\t)\n'
                         f'\t\t(stroke\n\t\t\t(width 0)\n\t\t\t(type default)\n\t\t)\n\t\t(uuid "{uid()}")\n\t)\n')

    def seg(self, *pts):
        for a, b in zip(pts, pts[1:]):
            if a != b: self.wire(a[0], a[1], b[0], b[1])

    def junc(self, x, y):
        self.body.append(f'\t(junction\n\t\t(at {x} {y})\n\t\t(diameter 0)\n\t\t(color 0 0 0 0)\n\t\t(uuid "{uid()}")\n\t)\n')

    def label(self, name, x, y, side='L', ang=0):
        just = 'right' if side == 'L' else 'left'
        self.body.append(f'\t(label "{name}"\n\t\t(at {x} {y} {ang})\n\t\t(effects\n\t\t\t(font\n'
                         f'\t\t\t\t(size 1.27 1.27)\n\t\t\t)\n\t\t\t(justify {just})\n\t\t)\n\t\t(uuid "{uid()}")\n\t)\n')

    def stub(self, ref, unit, pin, name, side=None, ln=5.08):
        pp = self.pins(ref, unit)[pin]
        X = self.placed[(ref, unit)][0]
        side = 'L' if pp[0] < X else 'R'   # auto: stub points away from the body
        dx = -ln if side == 'L' else ln
        e = (round(pp[0]+dx, 2), pp[1])
        self.wire(pp[0], pp[1], e[0], e[1])
        self.label(name, e[0], e[1], side)

    def vstub(self, ref, unit, pin, name, up=True, ln=5.08):
        pp = self.pins(ref, unit)[pin]
        e = (pp[0], round(pp[1]+(-ln if up else ln), 2))
        self.wire(pp[0], pp[1], e[0], e[1])
        self.label(name, e[0], e[1], 'L', 90)

    def power(self, ref, unit, pin, kind='VCC', down=False):
        self._use('power:'+kind)
        pp = self.pins(ref, unit)[pin]
        pr = uid()
        s = (f'\t(symbol\n\t\t(lib_id "power:{kind}")\n\t\t(at {pp[0]} {pp[1]} {180 if down else 0})\n\t\t(unit 1)\n'
             '\t\t(exclude_from_sim no)\n\t\t(in_bom no)\n\t\t(on_board yes)\n\t\t(dnp no)\n'
             f'\t\t(uuid "{pr}")\n')
        s += self.prop("Reference", "#PWR", pp[0], pp[1], hide=True)
        s += self.prop("Value", 'VCC' if kind == 'VCC' else 'GND', pp[0]+3.81, pp[1])
        s += f'\t\t(pin "1"\n\t\t\t(uuid "{uid()}")\n\t\t)\n'
        s += ('\t\t(instances\n\t\t\t(project "mnymny"\n'
              f'\t\t\t\t(path "{self.instpath}"\n\t\t\t\t\t(reference "#PWR")\n\t\t\t\t\t(unit 1)\n\t\t\t\t)\n\t\t\t)\n\t\t)\n')
        self.body.append(s + '\t)\n')

    def save(self, path):
        txt = self.head
        txt += '\t(lib_symbols\n'
        for b in self.libs.values():
            txt += '\t\t' + b.replace('\n', '\n\t\t') + '\n'
        txt += '\t)\n'
        txt += ''.join(self.body)
        txt += '\t(sheet_instances\n\t\t(path "/"\n\t\t\t(page "1")\n\t\t)\n\t)\n)\n'
        bal = txt.count('(') - txt.count(')')
        assert bal == 0, f'paren imbalance {bal}'
        open(path, 'w').write(txt)
        return path

import subprocess, os
def validate(path, render_to=None, width=3000):
    r = subprocess.run([CLI, 'sch', 'erc', path], capture_output=True, text=True)
    found = [l for l in r.stdout.splitlines() if 'Found' in l]
    ok = r.returncode == 0 or found
    out = {'erc': found[0] if found else r.stderr.strip()[-200:], 'load_ok': bool(found)}
    if render_to:
        os.makedirs(render_to, exist_ok=True)
        r2 = subprocess.run([CLI, 'sch', 'export', 'svg', path, '-o', render_to],
                            capture_output=True, text=True)
        out['export'] = 'ok' if r2.returncode == 0 else ('FAIL: '+r2.stderr[-200:])
        if r2.returncode == 0:
            svg = os.path.join(render_to, os.path.basename(path).replace('.kicad_sch', '.svg'))
            png = svg.replace('.svg', '.png')
            subprocess.run(['rsvg-convert', '-w', str(width), svg, '-o', png])
            out['png'] = png
    return out

# ---------------- programmatic symbol builder ----------------
def boxsym(name, left, right, vcc=None, gnd=None, ref='U', width=25.4, desc=''):
    """Rectangular symbol. left/right = [(number,name,ptype),...] top->bottom.
    vcc/gnd = pin numbers (drawn top/bottom center). Returns the symbol block."""
    n = max(len(left), len(right))
    h2 = SN((n+1)*2.54/2 + 2.54)          # half-height
    w2 = SN(width/2)
    def pin(num, nm, ptype, x, y, ang):
        inv = 'inverted' if nm.startswith('~') else 'line'
        nmk = re.sub(r'~([A-Za-z0-9]+)', r'~{\1}', nm)
        return (f'\t\t\t(pin {ptype} {inv}\n\t\t\t\t(at {x} {y} {ang})\n\t\t\t\t(length 5.08)\n'
                f'\t\t\t\t(name "{nmk}"\n'
                f'\t\t\t\t\t(effects\n\t\t\t\t\t\t(font\n\t\t\t\t\t\t\t(size 1.27 1.27)\n\t\t\t\t\t\t)\n\t\t\t\t\t)\n\t\t\t\t)\n'
                f'\t\t\t\t(number "{num}"\n'
                f'\t\t\t\t\t(effects\n\t\t\t\t\t\t(font\n\t\t\t\t\t\t\t(size 1.27 1.27)\n\t\t\t\t\t\t)\n\t\t\t\t\t)\n\t\t\t\t)\n\t\t\t)\n')
    pins = ''
    for i, (num, nm, pt) in enumerate(left):
        y = SN(h2 - 5.08 - i*2.54)
        pins += pin(num, nm, pt, -w2-5.08, y, 0)
    for i, (num, nm, pt) in enumerate(right):
        y = SN(h2 - 5.08 - i*2.54)
        pins += pin(num, nm, pt, w2+5.08, y, 180)
    if vcc: pins += pin(vcc, 'VCC', 'power_in', 0, h2+5.08, 270)
    if gnd: pins += pin(gnd, 'GND', 'power_in', 0, -h2-5.08, 90)
    return (f'(symbol "{name}"\n'
        '\t(exclude_from_sim no)\n\t(in_bom yes)\n\t(on_board yes)\n'
        f'\t(property "Reference" "{ref}"\n\t\t(at {-w2} {h2+2.54} 0)\n'
        '\t\t(effects\n\t\t\t(font\n\t\t\t\t(size 1.27 1.27)\n\t\t\t)\n\t\t\t(justify left)\n\t\t)\n\t)\n'
        f'\t(property "Value" "{name}"\n\t\t(at {-w2} {-h2-2.54} 0)\n'
        '\t\t(effects\n\t\t\t(font\n\t\t\t\t(size 1.27 1.27)\n\t\t\t)\n\t\t\t(justify left)\n\t\t)\n\t)\n'
        '\t(property "Footprint" ""\n\t\t(at 0 0 0)\n'
        '\t\t(effects\n\t\t\t(font\n\t\t\t\t(size 1.27 1.27)\n\t\t\t)\n\t\t\t(hide yes)\n\t\t)\n\t)\n'
        f'\t(property "Description" "{desc}"\n\t\t(at 0 0 0)\n'
        '\t\t(effects\n\t\t\t(font\n\t\t\t\t(size 1.27 1.27)\n\t\t\t)\n\t\t\t(hide yes)\n\t\t)\n\t)\n'
        f'\t(symbol "{name}_0_1"\n'
        f'\t\t(rectangle\n\t\t\t(start {-w2} {h2})\n\t\t\t(end {w2} {-h2})\n'
        '\t\t\t(stroke\n\t\t\t\t(width 0.254)\n\t\t\t\t(type default)\n\t\t\t)\n'
        '\t\t\t(fill\n\t\t\t\t(type background)\n\t\t\t)\n\t\t)\n\t)\n'
        f'\t(symbol "{name}_1_1"\n{pins}\t)\n)')

def add_to_locallib(blocks, lib='cores/mnymny/sch/mnymny.kicad_sym'):
    s = open(lib).read().rstrip()
    assert s.endswith(')')
    body = s[:-1]
    for b in blocks:
        nm = b.split('"')[1]
        if f'(symbol "{nm}"' in body:
            continue
        body += '\t' + b.replace('\n', '\n\t') + '\n'
    open(lib, 'w').write(body + ')\n')

def _sheet_stubx(self, ref, pin, name, ln=5.08):
    """stub on whichever placed unit of ref owns this pin"""
    for (r,u) in self.placed:
        if r==ref and pin in self.pins(r,u):
            return self.stub(r,u,pin,name,ln=ln)
    raise SystemExit(f'{ref}: no placed unit owns pin {pin}')
def _sheet_powerx(self, ref, pin, kind='VCC', down=False):
    for (r,u) in self.placed:
        if r==ref and pin in self.pins(r,u):
            return self.power(r,u,pin,kind,down=down)
    raise SystemExit(f'{ref}: no placed unit owns pin {pin}')
Sheet.stubx = _sheet_stubx
Sheet.powerx = _sheet_powerx

# ---------------- bus support (risle style) ----------------
def _sheet_bus_seg(self, *pts):
    """polyline bus trunk through the given points"""
    for a, b in zip(pts, pts[1:]):
        if a != b:
            self.body.append(
                f'\t(bus\n\t\t(pts\n\t\t\t(xy {a[0]} {a[1]}) (xy {b[0]} {b[1]})\n\t\t)\n'
                f'\t\t(stroke\n\t\t\t(width 0)\n\t\t\t(type default)\n\t\t)\n\t\t(uuid "{uid()}")\n\t)\n')
def _sheet_buslabel(self, name, x, y, ang=90):
    self.body.append(
        f'\t(label "{name}"\n\t\t(at {x} {y} {ang})\n\t\t(effects\n\t\t\t(font\n'
        f'\t\t\t\t(size 1.27 1.27)\n\t\t\t)\n\t\t\t(justify left)\n\t\t)\n\t\t(uuid "{uid()}")\n\t)\n')
def _sheet_bus_entry(self, x, y, dx, dy):
    """entry whose wire side is at (x,y), landing on the bus at (x+dx,y+dy)"""
    self.body.append(
        f'\t(bus_entry\n\t\t(at {x} {y})\n\t\t(size {dx} {dy})\n'
        f'\t\t(stroke\n\t\t\t(width 0)\n\t\t\t(type default)\n\t\t)\n\t\t(uuid "{uid()}")\n\t)\n')
def _sheet_stub_bus(self, ref, pin, net, trunk_x):
    """label stub from pin, extended into a vertical bus trunk at trunk_x"""
    for (r, u) in self.placed:
        if r == ref and pin in self.pins(r, u):
            pp = self.pins(r, u)[pin]
            X = self.placed[(r, u)][0]
            side = 'L' if pp[0] < X else 'R'
            if trunk_x < pp[0]:
                ex = round(trunk_x + 2.54, 2); dx = -2.54
            else:
                ex = round(trunk_x - 2.54, 2); dx = 2.54
            self.wire(pp[0], pp[1], ex, pp[1])
            lx = round(pp[0] + (-2.54 if side == 'L' else 2.54), 2)
            self.label(net, lx, pp[1], side)
            self._bus_taps.setdefault(round(trunk_x, 2), []).append(pp[1])
            self.bus_entry(ex, pp[1], dx, -2.54)
            return
    raise SystemExit(f'{ref}: no placed unit owns pin {pin}')
def _sheet_bus_close(self, trunk_x, name=None, ytop=None, ybot=None):
    """draw the vertical trunk covering all taps registered at trunk_x"""
    taps = self._bus_taps.get(round(trunk_x, 2), [])
    if not taps: return
    y1 = min(taps) - 2.54 - 5.08 if ytop is None else ytop
    y2 = max(taps) - 2.54 + 5.08 if ybot is None else ybot
    self.bus_seg((trunk_x, round(y1, 2)), (trunk_x, round(y2, 2)))
    if name:
        self.buslabel(name, trunk_x, round(y1 + 1.27, 2), 90)
Sheet.bus_seg = _sheet_bus_seg
Sheet.buslabel = _sheet_buslabel
Sheet.bus_entry = _sheet_bus_entry
Sheet.stub_bus = _sheet_stub_bus
Sheet.bus_close = _sheet_bus_close
Sheet._bus_taps = None
_old_sheet_init = Sheet.__init__
def _new_sheet_init(self, *a, **k):
    _old_sheet_init(self, *a, **k)
    self._bus_taps = {}
Sheet.__init__ = _new_sheet_init

# ---------------- channel router: real wires between same-page pins ----------------
def _sheet_pinabs(self, ref, pin):
    for (r, u) in self.placed:
        if r == ref and pin in self.pins(r, u):
            pp = self.pins(r, u)[pin]
            X = self.placed[(r, u)][0]
            return pp, ('L' if pp[0] < X else 'R')
    raise SystemExit(f'{ref}: no placed unit owns pin {pin}')
def _sheet_connect(self, refA, pinA, refB, pinB, net=None, ch=None, stub=2.54):
    """Manhattan route A->B: stubs outward, vertical channel between them.
    Optional net label placed mid-run. ch = channel x override."""
    a, sa = self._pinabs(refA, pinA)
    b, sb = self._pinabs(refB, pinB)
    ea = (round(a[0] + (stub if sa == 'R' else -stub), 2), a[1])
    eb = (round(b[0] + (stub if sb == 'R' else -stub), 2), b[1])
    if ch is None:
        ch = SN((ea[0] + eb[0]) / 2)
    self.wire(a[0], a[1], ea[0], ea[1])
    self.wire(b[0], b[1], eb[0], eb[1])
    if ea[1] == eb[1]:
        self.wire(ea[0], ea[1], eb[0], eb[1])
    else:
        self.seg(ea, (ch, ea[1]), (ch, eb[1]), eb)
    if net:
        self.label(net, ch, round(min(ea[1], eb[1]) - 1.27, 2), 'R', 0)
Sheet._pinabs = _sheet_pinabs
Sheet.connect = _sheet_connect
