# YM2151 measurement archive

The original campaign checkpoint is `342decb02fbc6c4ae9413f67b84162b9344a3dee`.
The permanent archive starts at `/gdrive/jotego/reverse/YM2151/README.md`.
Its campaign directory is
`2026-10-18-diet-go-go-jtcores-143/`.

`measurements.tar.zst` contains the complete original task tree: 113,577
regular files (13,325,203,551 uncompressed bytes) and 14 symlinks. This
includes raw captures, decoded data, full register histories, model outputs,
failed attempts, qualifications, build inputs and source identity evidence.
Every member was independently streamed and checked against the original
SHA-256 inventory. The compressed archive is 3,265,795,011 bytes, SHA-256
`732616e5cc41171c129ff4e1a1a017b5047cd614aa814f060260f7c4da4592d9`.

`MEASUREMENTS.md` indexes the original subsystem reports. `FIGURES.md` and
`browse/` expose 109 original figures and their reports without extracting
the archive. The 127 browsable copies were independently hash checked.
`sources/` preserves production jt51 `985a573`, external OPM `a0ab44`,
PicoROM `c2fa947`, the capture source and earlier inconclusive X-Men attempts.
Those earlier attempts are not positive controls for the replacement bench.

The direct-serial Diet Go Go bench uses the 28-pin PicoROM, the HuC6280
resident monitor and the inverting adapter. The measured master clock is
3.57–3.58 MHz with 0.01 MHz tolerance. See [validation.md](validation.md) for
hardware, decoding, conditioning and timing provenance.

To check or extract the original archive:

```sh
python3 verify-archive.py
mkdir extracted
zstd -dc measurements.tar.zst | tar -xf - -C extracted
```

Run these commands in the archive campaign directory. The verifier requires
standard Python and zstd. The archive member root is `jtcores-143/`.
Original absolute provenance paths resolve by replacing
`/home/jtejada/jtcores-2/tasks/jtcores-143/` with `extracted/jtcores-143/`.
Historical pre-promotion source versions remain in the archived
`artifacts/prepromotion-baseline-v1/` mapping. Do not rewrite old source
hashes or scientific indices to match current promoted sources.

The complete reconciliation supplement is `supplement-measurements.tar.zst`:
87,480 regular files (6,377,724,208 logical uncompressed bytes) and two symlinks.
Its 759,989,183 compressed bytes have SHA256
`c02ff34d2018f57dca6ab24e27af016a3e50104e03ff568ef762840f689ac8c0`.
Every archived file/link was independently decompressed and checked for original
SHA256, size, mode and link target against `supplement-files.jsonl` (SHA256
`b4065c033c1431abfb2689d91c553288c7d2929e54838a9c997b81deacc06f14`).
`supplement-archive-verification.json` records the successful full check and
exclusive final installation. The original archive remains unchanged.

The supplement contains the ENTIRE `tasks/ym2151-archive-20261018/` task:
raw captures, full register histories, models, source snapshots, original
failed/partial attempts, qualifications, individual results, figures and reviews.
It was frozen only after all physical/model/scorer/join/audit producers ended.
Final archive hashes, issue readbacks and source-commit proofs are outside that
sealed task, under the campaign's `issue-reconciliation-final/` and
`final-source-publication/`. The final committed documentation/source snapshot
and its identity proof are under `sources/`. Pre-seal prose candidates remain
in the supplement's `artifacts/publication-source-checkpoint-v1/`; its older
archive-guide snapshot necessarily precedes this final archive hash.

`SUPPLEMENT.md` and `supplement-browse/` expose the completed pitch/level,
live/key-history, all-code LFO and reconciliation reports plus five PNG figures
and three LFO PDFs. Detailed source/raw references outside the selected browse
set are available in the full archives. Both archives keep partial/unresolved,
failed-qualification and conditional model observations as originally recorded.
Archive integrity does not turn them into a chip pass.

From the campaign directory, verify and extract the supplement alongside the
original task:

```sh
python3 verify-archive.py supplement-measurements.tar.zst --manifest supplement-files.jsonl
zstd -dc supplement-measurements.tar.zst | tar -xf - -C extracted
```

Its member root is `ym2151-archive-20261018/`. Replace the old absolute prefix
`/home/jtejada/jtcores-2/tasks/ym2151-archive-20261018/` with
`extracted/ym2151-archive-20261018/` when consulting provenance. Scientific pins
to earlier `jtcores-143/` documents resolve to the immutable original archive;
the later publication prose is preserved separately in the final Git snapshot.
Do not overwrite the original extracted sources or revise old scientific hashes
to match later prose. The [reconciliation](reconciliation.md) report explicitly
retains the unavailable original Rastan trace as an essential input blocker.
