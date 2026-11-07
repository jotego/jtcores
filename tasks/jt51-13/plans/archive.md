# Replacement-history archive

The measurement artifact archive is complete and fully verified. The case is
`/gdrive/jotego/reverse/YM2151/2026-10-18-rastan-history-jt51-13/`.
The earlier sealed campaign remains in the sibling
`2026-10-18-diet-go-go-jtcores-143/`; its original and supplemental archives are
unchanged. This new case contains the user-authorized replacement input, not
the recovered original98880-write Rastan CSV.

The publication separates immutable measurement artifacts from the final
committed source snapshot, so the source reports can cite the finished archive
without a circular self-hash:

- `measurements.tar.zst`: every file and link under
  `tasks/jt51-13/artifacts/`, including the complete MAME recordings, all116
  physical capture containers, original failures and superseded windows,
  literal monitor programs, host bounds, raw/model outputs, descriptor reports,
  build/test inputs, runtime producer snapshots, figures and saved-output audits.
- `task-files.jsonl` and `archive-member-verification.json`: original per-member
  SHA256/size/mode/link inventory and full decompressed-member verification.
- `sources/`: the final Git task-source snapshot, source-publication proof and
  frozen JT51, external OPM and PicoROM source archives. The latter are exact
  copies of the verified source archives from the prior case.
- `replacement-trace/`: directly browsable compressed canonical bus and compatible
  register CSV, exact saved recorder source, invocation and input/output hashes.
- Browse reports/figures, final issue readbacks and source/push proofs are outside
  the data archive. They bind the final publication without changing its members.

The source Git archive retains the `tasks/jt51-13/` path. Extract it into the same
directory as the measurement archive to reconstruct one task tree. Check the
data archive from the case directory:

```sh
python3 verify-archive.py measurements.tar.zst --manifest task-files.jsonl
mkdir extracted
zstd -dc measurements.tar.zst | tar -xf - -C extracted
# Choose the exact committed task-source filename from SOURCE-PUBLICATION.json.
zstd -dc sources/jtcores-jt51-13-COMMIT.tar.zst | tar -xf - -C extracted
```

Replace the original absolute prefix `/home/jtejada/jtcores-2/` in provenance
with `extracted/` when consulting local files. Absolute paths identify where the
measurements ran; they are not a requirement to recreate the old workstation.
Recorded monitor state is historical and is not proof that a newly connected
board is in that state. Hardware execution requires a fresh live qualification.

The canonical bus uses integer seconds/attoseconds and preserves the first
elapsed interval. The compatible headerless register CSV starts with delta0;
use its adjacent bus/capture metadata when elapsed history matters. The source
clock is4MHz; the actual bench is nominal3.58MHz. Recorded host gaps and CPU/model
overhead remain explicit limits, not hidden alignment corrections.

After every producer terminates, `scripts/archive-artifacts.py` inventories the
stopped artifacts, compresses them, checks source membership/content again,
decompresses and verifies every member, then installs the final archive using an
atomic hard link that refuses to replace an existing final file. The final case
checksum manifest is sealed only after source publication and issue readbacks.
Integrity verification does not convert unresolved audio features into a chip
conformance pass.

## Verified artifact publication

`measurements.tar.zst` contains8317 regular files, no symlinks, and1118087413
uncompressed bytes. Its compressed size is92669659 bytes. The stopped source
membership/content check and full decompressed per-member verification both
passed; the final file was installed without replacing any existing archive.

Archive SHA256:
`9a967b16f3259faf3ee09289708dd9405c49894228c365d3d82f220e72cb3f47`

Inventory SHA256:
`2a4910e2ecf3137f22f23a95c0d98dbfdac3d7441cb97a37b8998eaa7a923f25`

`archive-member-verification.json` records the actual verifier exit0, all8317
members and the no-clobber installation. Source publication, final issue bodies,
comments and live status/dependency readbacks are retained separately under
`final-publication/`; they never alter the verified measurement members.
The final committed source archive and its commit/push proof are indexed by
`SOURCE-PUBLICATION.json`. The case's `SHA256SUMS` is written last, after those
publication files. Its independent verification proof is outside the sealed
case, beside the parent index.

There are seven scoped implementation requirements: the original six plus the
new finite low-RR release requirement. Their [inventory](gaps.md) and
[low-release evidence](low-release.md) distinguish measured behavior from
internal causes. No JT51 RTL or external-model algorithm was changed.
