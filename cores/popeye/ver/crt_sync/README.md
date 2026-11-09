# Native field sync through JTFRAME

The timing test uses Popeye's generated 7J PROM fixture and routes the PCB
HS/VS/blanking outputs through `jtframe_resync` at default CRT offsets and the
native pixel enable. It checks the 164160-pixel (256.5-line) period, alternating
half-line VSync phases, and output VSync edge timing against the PCB in absolute
time. The test catches both a double-rate sampling enable and selection of the
opposite stored field, even when the latter has apparently matching phase by
field index.
Run with `simunit.sh --run cores/popeye/ver/crt_sync`.
