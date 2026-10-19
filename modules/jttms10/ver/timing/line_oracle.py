# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent LINE timing: TI SPVU001A pp.12-102..104 and5-24.

Counts describe window processing before plane masking/transparency. The
guide includes those effects in P; suppressed physical writes do not turn
processed pixels into window-rejected pixels. No RTL or measured count is read.
"""


class UnresolvedLineTiming(ValueError):
    def __init__(self, message, alternatives=None):
        super().__init__(message)
        self.alternatives = alternatives or {}


def pixel_states(pixel_size, ppop):
    """Table12-11,p12-103. Preserve its duplicated SUBS/missing SUB labels."""
    if pixel_size not in (1, 2, 4, 8, 16) or ppop not in range(22):
        raise ValueError('undefined pixel size or processing operation')
    if ppop >= 16 and pixel_size < 4:
        raise ValueError('arithmetic pixel processing requires at least four bits')
    if ppop == 18:
        raise UnresolvedLineTiming('Table12-11 does not name ordinary SUB')
    if ppop == 19:
        raise UnresolvedLineTiming('Table12-11 names SUBS in both columns',
                                   dict(first_subs_column=5, last_subs_column=6))
    return 2 if ppop == 0 else 4 if ppop <= 16 else 5


def line_timing(*, drawn, outside=0, window=0, violation=False,
                pixel_size=16, ppop=0, cache_disabled=False,
                plane_mask=False, transparency=False):
    """Return the setup/transfer decomposition, in TI machine states.

    drawn=E and outside=q describe pixels that pass/fail the window test.
    W=1 hit/miss terminal accounting remains explicitly unresolved. W=2
    can encounter exactly one rejected pixel before aborting. The empty
    W=0/2/3 sequence has no transfers and retains the four setup states.
    """
    if any(type(x) is not int or not 0 <= x <= 0xFFFFFFFF for x in (drawn, outside)):
        raise ValueError('pixel counts must be unsigned 32-bit integers')
    if drawn + outside > 0xFFFFFFFF or window not in range(4):
        raise ValueError('invalid total count or window mode')
    if window == 1:
        if drawn:
            raise ValueError('window-hit LINE never draws pixels')
        raise UnresolvedLineTiming(
            'Table12-10 W1 terminal +5 and whether q includes the hit need resolution',
            dict(printed_q_term=5*outside+5, excludes_terminal_hit=5*outside))
    if window == 0 and (outside or violation):
        raise ValueError('W0 cannot reject a pixel')
    if window == 2 and outside != int(bool(violation)):
        raise ValueError('W2 aborts on its first rejected pixel')
    if window == 3 and violation:
        raise ValueError('W3 clips without aborting')
    p = pixel_states(pixel_size, ppop)
    transfer = (3+p)*drawn + 5*outside
    setup = 4
    # Single-word LINE; general cache rule in5.4.7,p5-24 and13.1,p13-2.
    fetch = 3*bool(cache_disabled)
    return dict(states=setup+transfer+fetch, setup_states=setup,
                transfer_states=transfer, fetch_states=fetch, pixel_states=p,
                drawn=drawn, outside=outside, window=window,
                plane_mask=bool(plane_mask), transparency=bool(transparency),
                clock_unit='TI machine states',
                citation='SPVU001A12-102..104 Tables12-10/11;5-24;13-2')
