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

The separately acquired reconciliation supplement is tracked under
`tasks/ym2151-archive-20261018/`. Its archive, final inventory, issue
reconciliation and verification are listed in the permanent archive index
when complete. The original archive remains immutable. A failed numerical
feature, unresolved slow/random behavior or old invalid acquisition remains
part of the evidence; archive integrity does not turn it into a chip pass.
