# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent FILL state counts: TI SPVU001A13-10..14.

Inputs describe the positive, already-clipped destination rectangle. This
model reads no RTL, microcode or simulator observations. Counts exclude
external waits, other bus owners and interrupt/context-switch effects.
Unresolved source cases raise instead of becoming implicit timing goldens.
"""


class UnresolvedFillTiming(ValueError):
    def __init__(self, message, alternatives=None):
        super().__init__(message)
        self.alternatives = alternatives or {}


def graphics_states(pixel_size, ppop, *, plane_mask=False, transparency=False):
    """Table13-7,p.13-13; arithmetic size restriction on12-81."""
    if pixel_size not in (1, 2, 4, 8, 16) or ppop not in range(22):
        raise ValueError('undefined pixel size or processing operation')
    if ppop >= 16 and pixel_size < 4:
        raise ValueError('arithmetic PPOP is undefined for one/two-bit pixels')
    base = 2 if ppop == 0 else 4 if ppop <= 16 else 6 if ppop == 19 else 5
    return base + (2 if plane_mask or transparency else 0)


def fill_timing(*, pixel_size, width, rows, address=0, pitch=16, xy=False,
                window_operation='disabled', ppop=0, plane_mask=False,
                transparency=False, cache_disabled=False):
    """Return the cited setup/transfer/adjustment decomposition in states.

    Window operation identifies the *result* of preclipping, not raw W bits.
    All rows must retain one alignment class. The single-row case needs no
    pitch restriction because it has no following row to change alignment.
    """
    if not 0 <= width <= 65535 or not 0 <= rows <= 65535:
        raise ValueError('DX and DY must fit their unsigned 16-bit fields')
    if width == 0 or rows == 0:
        raise UnresolvedFillTiming('exact empty-array timing remains unaudited')
    if not 0 <= address <= 0xFFFFFFFF or not 0 <= pitch <= 0xFFFFFFFF:
        raise ValueError('linear address and pitch must fit 32 bits')
    g = graphics_states(pixel_size, ppop, plane_mask=plane_mask,
                        transparency=transparency)
    if address % pixel_size:
        raise ValueError('pixel-aligned destination required (SPVU001A7-10)')
    if rows > 1 and pitch % 16:
        raise UnresolvedFillTiming('varying row alignment has only average/worst estimates on13-12')
    setup_values = dict(disabled=6, fits=9, start=16, dimensions=12, both=20)
    if not xy and window_operation != 'disabled':
        raise ValueError('FILL L has no clipping operation')
    if window_operation in ('hit', 'miss'):
        raise UnresolvedFillTiming('Table13-5 hit/miss dashes do not supply exact counts')
    if window_operation not in setup_values:
        raise ValueError('use a documented FILL XY setup result')
    setup = (setup_values[window_operation] if xy else 4) + 3 * bool(cache_disabled)
    lane = address & 15
    span = lane + width * pixel_size
    words = (span + 15) // 16
    alignment = ('A' if span % 16 == 0 else 'B') if lane == 0 else ('C' if span % 16 == 0 else 'D')
    # Table13-6,p.13-11. N=3 belongs to the long case (p.13-12).
    if words == 1:
        row_work, tail = (1 + g, 2) if alignment == 'A' else (2 + g, 2 if alignment == 'B' else 1)
    elif words == 2:
        row_work = dict(A=2, B=3, C=3, D=4)[alignment] + 2 * g
        tail = 1 if alignment == 'D' else 2
    else:
        row_work = dict(A=1, B=2, C=3, D=4)[alignment] + words * g
        tail = dict(A=2, B=5, C=2, D=1)[alignment]
    transfer = row_work * rows + tail
    adjustment = 0
    if plane_mask or transparency:
        edges = dict(A=0, B=1, C=1, D=2)[alignment]
        adjustment = 2 * edges * rows
        if words == 1 and alignment == 'D':
            raise UnresolvedFillTiming(
                '13-14 subtracts two edge reads although both edges share one word; interpretation required',
                dict(printed_two_edges=setup + transfer - adjustment,
                     single_word_edge=setup + transfer - 2 * rows))
    return dict(states=setup + transfer - adjustment, setup_states=setup,
                transfer_states=transfer, adjustment_states=adjustment,
                words_per_row=words, alignment=alignment, word_states=g,
                clock_unit='TI machine states', citation='SPVU001A13-10..14')
