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
