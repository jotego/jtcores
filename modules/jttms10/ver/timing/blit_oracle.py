# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent aligned opaque PIXBLT counts, TI SPVU001A13-18..35.

This first domain is W0/PBH0/PBV0/PPOP0/PMASK0/T0, nonempty arrays with
word-aligned source and destination rows. Binary rows contain at most 32 bits.
Other conditions need their own cited equations; no simulator/RTL is read.
"""


class UnresolvedBlitTiming(ValueError):
    pass


def blit_timing(mode, pixel_size, words, rows, *, cache_disabled=False):
    """Tables13-8/9/10 and13-11/12/13, G=2, destination alignment A."""
    setup = dict(ll=7, lxy=9, xyl=9, xyxy=12, bl=4, bxy=6)
    if mode not in setup or type(pixel_size) is not int or pixel_size not in (1, 2, 4, 8, 16):
        raise ValueError('undefined PIXBLT mode or pixel size')
    if type(words) is not int or type(rows) is not int or words <= 0 or not 1 <= rows <= 65535:
        raise ValueError('positive word count and unsigned nonzero DY required')
    width = words * 16 // pixel_size
    if width > 65535:
        raise ValueError('DX exceeds its unsigned sixteen-bit field')
    binary = mode in ('bl', 'bxy')
    if binary:
        if width > 32:
            raise UnresolvedBlitTiming('long binary rows require the separate set/remainder audit')
        source_words = (width + 15) // 16
        row_states = 3 + 2 * source_words + 2 * words
        tail = 3
    else:
        source_words = words
        row_states = 6 if words == 1 else 10 if words == 2 else 4 * words
        tail = 5
    fetch = 3 * bool(cache_disabled)
    return dict(states=setup[mode] + row_states * rows + tail + fetch,
                setup_states=setup[mode], row_states=row_states,
                transfer_states=row_states * rows + tail, tail_states=tail,
                fetch_states=fetch, source_words_per_row=source_words,
                destination_words_per_row=words, width=width,
                clock_unit='TI machine states',
                citation='SPVU001A13-18/20/24;13-32..35')
