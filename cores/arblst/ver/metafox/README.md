# Meta Fox video regression (issue #1681)

The registration regression uses the **second attract loop**, with no coin or
Start input. Frames 2700/2800/2900 show silver cannon pivots against red circular
pedestals. The original MAME references share the registration error and are
historical evidence; matching them does not prove correct alignment. Original
captures, MiSTer photographs and the corrected-reference experiment are kept
separate under `tasks/jtcores-1681/artifacts`.

Use the maintained `~/mame/scene` binary with the arblst payload extension
(34828 bytes, full 16 KB external sprite RAM), and a separate cfg directory:

```sh
mkdir -p "$JOTEGO/scenes/arblst/metafox" /tmp/arblst-mame-cfg
ln -s "$JOTEGO/scenes/arblst/metafox" scenes
METAFOX_FLIP=2 timeout 5m ~/mame/scene/mame metafox -window \
  -dump_scenes 2700,2800,2900 -jtcore_path "$JTROOT/cores/arblst" \
  -autoboot_script "$PWD/attract.lua" -autoboot_delay 0 \
  -cfg_directory /tmp/arblst-mame-cfg
```

Rename numbered folders before repeating with `METAFOX_FLIP=0`. The dump's last
four bytes are X1-001 controls; cfg0 bit 6 confirms normal versus flipped.
`attract.lua` sets only the Flip Screen DIP and supplies no cabinet inputs.

`capture.lua` and `start.cab` are separate gameplay helpers: coin on frames
600–603, Start on 800–829, captures at 850/900/1000/1200. These scenes validate startup edges and
scrolling but initially missed the cannon registration defect. The earlier
8/8 exact-MAME-match result is superseded by the attract registration checks.

```sh
jtframe mra arblst
jtutil sdram metafox
jtsim -batch -s registered-normal-attract-2800
jtsim -batch -s registered-flip-attract-2800
```

`jtutil sdram` is essential: scene mode shortens the ROM download and needs all
four `sdram_bank*.bin` preloads. A missing preload renders a black frame.
The simulator keeps flipped games upright using `dip_flip`, so raw MAME flipped
references need 180-degree normalization. Preserve their raw originals.

The alignment has been confirmed on MiSTer. The temporary `debug_bus` sprite
trim has been removed; foreground origins are fixed and the bus retains its
normal diagnostic role.

Exact MAME patches and their apply order are recorded under
`tasks/jtcores-1681/artifacts/mame/`, based on commit
`a0406121daef738e468628e4b987f9cc14d80cca`. Payload support is permanent tooling;
render-only reference experiments are explicitly labeled and reverted after
capture. The final Meta Fox reference uses tile xoffsets normal 0 / flipped 125; the
captured machine state must remain bit-identical to the original dumps.
