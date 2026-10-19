# 054157 Verilog Deliverables

This directory contains the handoff bundle generated from the split HDL under
`artifacts/hdl/`.

## Files

- `jt054157_all.v`: single-file Verilog concatenated from
  `artifacts/hdl/jt054157.f`.
- `jt054157_all.md`: generation summary for the single-file HDL.
- `SHA256SUMS`: checksums for files in this deliverable directory.
- `SOURCE_SHA256SUMS`: checksums for the source files referenced by the HDL
  manifest.

## Scope

The current single-file HDL contains 106 manifest entries. It includes
the primitive cell catalog, audited page slices and integration checkpoints,
the internal connected boundary scaffold, and the package wrapper.

The primitive cell catalog is seeded from the completed 054156 extraction.
`audit_primitive_catalog_identity.py` checks that all 50 primitives shared
with 054156 are text-identical after chip-prefix normalization, and that the
only 054157-only additions are the documented `D24`, `N3B`, `N8B`,
`V2B`, and `X1B` cells.

The highest physical-input wrapper now exposes 86 physical split-input rails
and 3 documented semantic inputs: `hcnt1_raw`, `hcnt0_raw`, and
`page08_non_vc_pin_oe[15:0]`. Some lower-level page-slice modules still
preserve local schematic boundaries where that is the audited scope, but stale
page-1 raw/T2E helper ports and page-4 long-rail decode groups are rejected by
focused audits. See `../conversion.md` and the per-page findings under
`../extracted/` for the current ambiguity list.
`audit_completion_readiness.py` generates
`../extracted/completion_readiness_audit.md`, which maps the original
conversion objective to current evidence. The current handoff is expected
to report `candidate_complete` when all tracked evidence and boundary
checks remain clean.

The page-9/HOF/readout DB integration derives CPU DB output-enable bits from
`PIN_DB_LOWER_DIR` and `PIN_DB_UPPER_DIR`. The `DB_DIR_DRIVE_VALUE`
parameter remains available for bring-up override, but its default is treated
as the resolved active-low CPU DB convention from the completed 054156
package extraction.
`audit_page09_db_oe_package_order.py` verifies the byte grouping:
`PIN_DB_LOWER_DIR` controls DB0 through DB7 OE and `PIN_DB_UPPER_DIR`
controls DB8 through DB15 OE through the physical CPU DB package pins.
`audit_page09_integrated.py` now includes the full page-9 render and the
page-9 component-candidate table in its scope. It checks that all extracted
page-9 component candidates are accounted for by
`jt054157_page09_integrated.v` or documented extraction mispairs, so the old
bounded-slice concern about a separate middle-right page-9 logic island is
closed.

Page-11 CPU DB output bit order is audited from visible
`PIN_DB0_OUT` through `PIN_DB15_OUT` labels to `pin_db_out[15:0]`
packing and physical package outputs `pin_076_out` through
`pin_094_out` by `audit_page11_db_bus_order.py`. This resolves the DB
output bit order; DB output-enable active-low default is resolved by
cross-chip package evidence while still remaining configurable through
`DB_DIR_DRIVE_VALUE`.

The completed 054156 package-boundary audit is used only as pad-assumption
context. Its CPU DB OE default is active-low, and the 054157
`DB_DIR_DRIVE_VALUE` defaults to `1'b0` to match that convention. The
DB OE active-low default is treated as resolved for this handoff. This does
not prove the 054157 VC or non-VC/MF bidirectional pad truth table.
`VC_DIR_DRIVE_VALUE` is a documented configurable pad-policy parameter:
page 11 proves the `PINS_VC_DIR1..8` direction rail source and grouping,
while the parameter preserves the unproven pad-cell active level without
inventing logic. `page08_non_vc_pin_oe[15:0]` is the documented external
pad-policy input for the non-VC/MF bidirectional pads.
`audit_crosschip_pad_assumptions.py` guards this limited cross-chip use so
054156 context is not silently promoted into a proven 054157 pad rule.

The highest current page-8/page-9/HOF/readout checkpoint is wrapped by
`jt054157_page08_page09_hofs_readout_db_physical_input_package_integrated`.
That thin wrapper maps CPU DB input bits from physical package inputs
`pin_076_in` through `pin_094_in` and maps page-10/readout `PINnn_IN`
scalars to matching `pin_NNN_in` split rails. It also maps proven scalar
package inputs such as `PIN_CLK`, `PIN64`, `PIN112`, `PIN_AB1/2`,
`PIN_Z*`, `PIN_CROM`, `PIN_UDS`, `PIN_LDS`, `PIN95`, `PIN99`,
and `PIN113` to physical split-input rails. The mapping is guarded by
`audit_page08_page09_hofs_readout_db_physical_input_package_integrated.py`;
duplicated semantic package output aliases such as `pin101` and `pin114`
are hidden at this highest physical boundary in favor of the matching
`pin_NNN_out` rails. The same rule is applied to page-8 `pinNN_out`
aliases, while physical `pin_NNN_out` and `pin_NNN_oe` rails remain
exported. CPU DB `pin_db_out[15:0]` is hidden for the same reason, while
physical CPU DB `pin_NNN_out` and `pin_NNN_oe` rails remain exported.
Semantic direction outputs `pin_db_lower_dir`, `pin_db_upper_dir`, and
`pins_vc_dir[7:0]` are also hidden at this physical boundary while the
physical OE rails remain exported. The top physical checkpoint still exposes
and forwards `DB_DIR_DRIVE_VALUE` and `VC_DIR_DRIVE_VALUE`; DB keeps a
resolved active-low default with an override hook, while VC keeps a documented
configurable pad-policy parameter because the pad-cell truth table is outside
the recovered digital schematic.
`PIN_NRES` is bound to physical
`pin_109_in` at this checkpoint because page 2 visibly shows it driving
`K108A/FDO.R`; the package pin map preserves the spreadsheet's `OUT`
metadata but marks pin 109 as a schematic-direction override and emits input
HDL for the generated package scaffold.
`audit_page10_readout_source_top_boundary.py` guards the page-10 source
cleanup: the 10 former non-package readout helper rails are generated locally
from visible D24/V2B chains and must not be re-exposed in any higher wrapper.
The same audit rejects re-exposing the 16 D0-D7 `G*/V1N` selector inputs now
sourced from the dot-traced `J122A/G114A` vertical rail pair at the
page-10/11 wrapper. `audit_top_input_boundary_inventory.py` classifies every
input on this highest physical checkpoint: 86 are physical `pin_NNN_in`
split-input rails present in the package pin map, and 3 are documented
non-physical top inputs: `HCNT1_RAW/HCNT0_RAW` and page-8 non-VC OE bits.
`HCNT1_RAW/HCNT0_RAW` are documented internal cross-page connectors between
page 1 and page 7, not package-pin misses or unresolved completion blockers.
The former page-5 HOF data buses are now sourced from
physical `PIN_COL0..7` through the recovered page-5 selector. `K144_XQ` is now sourced from the
recovered page-1 lower-state rail inside the HOF/page-9 wrapper and no longer
appears as a top input. The former page-1 raw-counter
helper inputs and `J154/J138A/K139A` T2E source inputs are now sourced inside
the page-1/HOF wrappers and are rejected as top-level inputs. Page-9/readout `PIN116`
consumers are sourced from the recovered HOF
`PIN116` output rail and no longer appear as top-level semantic inputs. The
audit fails on any unclassified top input. For pin 109, the normalized pin map expects `PIN_NRES_IN` and
`PIN_NRES_OUT` aliases for audit coverage, but the recovered schematic text
only shows the bare `PIN_NRES` label. The focused reset crop shows that
`PIN_NRES` drives the active-low reset input of `K108A/FDO`, so the top
physical checkpoint binds inner `pin_nres` to physical `pin_109_in` while
the base package scaffold now also exposes physical `pin_109` as an input.
Physical pin 26 is classified as resolved negative evidence for this
schematic conversion: only `PIN26_OUT` is recovered, page-4/page-10 visual
contexts show repeated `PIN25_IN` rather than `PIN26_IN`, and the top
physical checkpoint exports `pin_026_out` and `pin_026_oe` while hiding the
duplicate semantic `pin26_out` alias. It does not synthesize a
`pin_026_in` route. `audit_pin26_vc_bidir_boundary.py` guards that
classification and rejects aliasing CPU `PIN_DB15_IN` to pin 26.

The page-8/page-9/HOF/readout integration sources page-8 `G124A` and
`REG6_D5` from recovered page-2/HOF logic. The page-8 left source-rail
matrix derives `DB0_8` through `DB7_15` plus
`P162B/P161A/L136B/L137B/N185B/N186B/N172B/N173B` from
`REG6_D5` and `PIN_DB0_IN` through `PIN_DB15_IN`. Page-8
`PIN_DB0_IN` through `PIN_DB15_IN` are sourced from shared CPU
`pin_db_in[15:0]` in the highest page-8/readout integration wrapper; the
page-9/HOF side consumes the low byte through an internal
`page09_pin_db_in` wire. Page-8 VC ROM-data pad OE is derived from the
recovered page-11 `PINS_VC_DIR*` shared rail, with the pad-cell active level
kept explicit by the documented `VC_DIR_DRIVE_VALUE` parameter. The 16-bit
`page08_non_vc_pin_oe[15:0]` vector is a documented external pad-policy
boundary for non-VC/MF bidirectional pads: the schematic proves the pads are
bidirectional and no internal OE/DIR/ENABLE source has been recovered.
`audit_page08_pin_oe_boundary.py` guards the boundary shape, and
`audit_page08_non_vc_oe_package_order.py` records the bit order from that
16-bit vector to physical OE rails for pins 2, 7, 8, 14, 15, 21, 22, 27, 28,
34, 35, 42, 43, 48, 49, and 159. `audit_page08_non_vc_inout_label_evidence.py`
separately checks that those same pins have page-8 `PIN*_OUT` labels and
page-10 `PIN*_IN` labels; `PIN49` remains the only member of the group
whose pin-map description is still `?` rather than `MF : VSS`.
`audit_page08_non_vc_oe_source_visibility.py` records that page 8 has the
expected visual tile coverage for these output labels but no recovered
OE/DIR/ENABLE-style control label. It also classifies the only recovered
schematic direction labels as the already-modeled page-9 CPU DB direction
rails and page-11 VC ROM-data direction rails, and checks that the 16 non-VC/MF
package rows have no recovered OE/DIR/ENABLE aliases. The OE source and active
polarity therefore remain explicit package-boundary information rather than
inferred HDL.
`audit_page08_non_vc_oe_physical_boundary.py` guards the same external
pad-policy vector at the outer physical-input wrapper:
`page08_non_vc_pin_oe[15:0]`
must pass unchanged into the inner package wrapper, while the 16 physical
`pin_NNN_oe` rails remain exported and no bit remapping, polarity conversion,
or constant tie-off is introduced at that outer layer.

`audit_hcnt_raw_crosspage_boundary.py` guards the page-1/page-7 H-counter
handoff as a resolved documented cross-page connector. It checks that both
pages recover `HCNT1_RAW` and `HCNT0_RAW`
labels, that page 1 separately generates shaped `HCNT2/1/0`, and that the
wrappers pass raw rails and shaped `hcnt[2:0]` separately without aliasing
`hcnt1_raw` to `hcnt[1]` or `hcnt0_raw` to `hcnt[0]`. It also checks
that the package pin map has no recovered `HCNT*` row or alias; the true
physical inputs in the same page-7 block are named separately as
`PIN_Z4H`, `PIN_Z2H`, and `PIN_Z1H`.

`audit_hofs_pipeline_pin_counter_integrated.py` guards the page-1/page-6
`C114B/H109_Q*` handoff. At the pin-counter HOF wrapper, `C114B` and
`H109_Q[3:0]` are outputs from the audited page-1 pin/counter slice, not
external input boundary ports; `H109_QA/QB/QC/QD` are mapped as
`h109_q[3]/[2]/[1]/[0]` into the page-6 decode path. The wrapper consumes
local lower-state `J156A/K153B/K137A` for `J154.A1/J138A.A1/K139A.B1`,
and the old `T2E` source ports are no longer wrapper inputs.
`audit_page01_t2e_boundary_visibility.py` guards that remaining
`J154/J138A/K139A` mux boundary: `J154.A2` and `J138A.B1` are driven by
the local `J161A` output, and `J154.B1` is tied to the visible local ground
symbol. `J154.B2/K139A.A1/K139A.A2` are driven by local
`K161/K155/K157` raw-counter outputs, `J138A.A2/J138A.B2` are driven by
local `J152A/J136A`, and `K139A.B2` shares the `J138A.A1` boundary net.
The three select pins are driven by
local `J161B`. In `jt054157_page01_partial.v`, `J154.A1` is sourced
from local `J156A`, `J138A.A1` from local `K153B`, and `K139A.B1`
from local `K137A`. The page-1 partial now also folds `L159.B` to local
`K153B` and both `K142` inputs to local `K160B/K137A`.
The HOF pin-counter wrapper now consumes those same recovered sources locally.
Stale per-mux select/data ports and reintroduced `t2e_s` are rejected; the
highest generated wrappers no longer expose the legacy page-1 raw/T2E source
ports.
`audit_page01_top_boundary_visibility.py` carries the active page-1
boundary contract up to the current highest physical-input wrapper:
`HCNT1_RAW/HCNT0_RAW` remain explicit top-level inputs and pass 1:1 into the
inner page-8/page-9/HOF/readout wrapper without constant ties. The former
raw-counter helper inputs, the `J154/J138A/K139A` T2E source inputs, and the
shared `t2e_s` boundary are driven internally and rejected at the top.
`audit_page09_k144_xq_boundary.py` records the current `K144_XQ`
decision: page 1 visibly generates `K144_XQ` from `K144/FDO` `/Q`, and
page 9 visibly consumes it. The recovered source is now passed through the HOF
package and consumed by page 9 as a hidden internal wire; the audit rejects
reintroducing `k144_xq` at the page-9/HOF or physical top boundaries and
checks that lower-state rails have not been propagated upward as replacement
top inputs.

`audit_page04_input_fds.py` guards the page-4 input-register pin-vector
order, including the non-obvious repeated `PIN25_IN` on the high BF and ED
groups. The visual crop shows `PIN25_IN` feeding both `D121/DD` and
`D168/DD`, so the audit rejects a pattern-filled `PIN26_IN` substitution.
`audit_page04_decode_integrated.py` guards the page-4 decode boundary: the
sixteen checked `N4N/N8B` cones stay integrated. The former ACOL2, ACOL3,
BCOL2, BCOL3, CCOL2, CCOL3, PIN57, PIN51, PIN53, PIN55, PIN52, PIN58, PIN56, PIN54, DCOL3, and DCOL4 long-rail boundary groups are now locally sourced from visible
`HOFSA_F/HOFSB_F/HOFSC_F/HOFSD_F` V2B chains and the
`M63/P43/J82/K75/P70/R70/J98/K85/J70/L95/N70/N55/F164/G206/E141/E180/E153/D180/F153/F195/D141/D131/C180/B180/B153/A139/C123/C153/J15/H15/M83/N96` second-stage FDS outputs. No page-4 long `N4N` input groups remain explicit `[3:0]` boundary inputs.
`audit_color_decode_package_integrated.py` carries that same page-4 boundary
contract through the color/package integration layer: ACOL2/ACOL3/BCOL2/BCOL3/CCOL2/CCOL3/PIN57/PIN51/PIN53/PIN55/PIN52/PIN58/PIN56/PIN54/DCOL3/DCOL4 consume
`hofsa_f/hofs_b_f/hofsc_f/hofsd_f` plus `m63_q/p43_q/j82_q/k75_q/p70_q/r70_q/j98_q/k85_q/j70_q/l95_q/n70_q/n55_q/f164_q/g206_q/e141_q/e180_q/e153_q/d180_q/f153_q/f195_q/d141_q/d131_q/c180_q/b180_q/b153_q/a139_q/c123_q/c153_q/j15_q/h15_q/m83_q/n96_q`, and the former one hundred twenty-eight page-4 long-rail groups are absent.

Page-10 readout scalar helper rails `H76A_Y` and `J109B_Y` are sourced
inside their local D10/D11 and D12/D13 slices from visible D24/V2B chains,
not exposed as integration boundary inputs.

`audit_page05_left_d24_integrated.py` guards the page-5 left-output D24
integration: `dcol_d/ccol_d/bcol_d/acol_d` remain the only upstream
`[3:0]` FDS data boundaries at that wrapper, while the eight `*_d24`
vectors are generated visible outputs rather than raw D24 boundary inputs.

`audit_page05_06_07_hofs_path_integrated.py` guards the page-5 HOF
first-stage data: `hofsd_d/hofsc_d/hofs_b_d/hofsa_d` are now sourced
inside the HOF pipeline from the page-5 `PIN_COL0..7` selector and remain
only as local page-slice ports. They pass directly into the page-5 HOF
flip slice and are not locally assigned in the cross-page wrapper.
`audit_page05_hofs_data_top_boundary.py` carries that same contract to the
current highest physical-input wrapper: the four buses must not appear as
top-level inputs, and `PIN_COL0..7` must feed the page-5 selector through the
page-8/page-9/HOF/readout wrapper chain without literal tie-offs.
`audit_top_semantic_boundary_ownership.py` cross-checks all 3 documented
non-physical top inputs against their owning evidence reports:
`hcnt0_raw`, `hcnt1_raw`, and `page08_non_vc_pin_oe`. It fails if a
semantic top input lacks an owner report, if an owner report has failing
checks, or if the owner port list drifts from the top-input inventory.

Page-10 D14/D15 helper rails `H139A_Y`, `J57B_Y`, `H150A_Y`, and
`H75A_Y` are also sourced inside the local slice from visible D24/V2B
chains. Their four underlying long coordinate rails are sourced at the
page-10/11 integration layer from the visible `G110A/H138A/H94B/H75B`
V2B chains.
Page-10 D8-D13 helper rails `J129B_Y`, `J109A_Y`, `J131A_Y`,
`J108A_Y`, `J130A_Y`, `H77B_Y`, `H150B_Y`, `J130B_Y`,
`J110B_Y`, and `J129A_Y` are sourced inside the page-10 wrapper from
visible D24/V2B chains; their only new package input needs are physical
`pin_042_in` and `pin_043_in`.

## Verification

`artifacts/scripts/verify_hdl.sh` regenerates these files and checks both the
split HDL and the single-file HDL with Icarus and Verilator.
