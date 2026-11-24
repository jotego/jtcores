# nuV30

This is a cycle-accurate FPGA recreation of the **NEC V30 (μPD70116)**, developed and
verified against real CPU hardware. A custom board connects the V30 to a DE-10 Nano, allowing the FPGA to drive the CPU inputs and read it's output. A test harness executes sequences of operations under various bus conditions and measures the responses. That information is use to infer internal hardware behavior and turn that into HDL code.

This is an experiment with AI driven hardware reverse engineering. Various agents were used throughout the process but mainly Anthropics Opus and Fable, and OpenAIs Sol. I have very little knowledge of the test harnesses that were built and the resulting CPU implementation. 

## Repository layout

| path | what |
|---|---|
| `de10_pcb/` | KiCad adapter board — schematic, PCB, fabrication outputs |
| `hdl/` | Quartus project: MiSTer harness, `rtl/ucore/` (the core), `rtl/core/` (archived FSM core), `tb/` (Verilator benches) |
| `sim/` | the microcode-driven C++ reference model (`v30sim`) |
| `sw/` | capture tools, suite emitter, scorers, and every standing gate |
| `tests/v30/` | golden suites captured from silicon |
| `docs/raw/`, `docs/converted/` | vendor manuals (scans + text) |
| `docs/facts/` | structured measured facts, each with provenance and a falsifier |
| `docs/notes/` | campaign ledgers, pre-registrations, results, verdicts |
| `docs/V20BITS.TXT`, `V20UC.TXT`, `V20UCDIS.PAS`, `pla_*.txt` | third-party microcode/PLA dumps — see attribution below |

---

## Sources and attribution

### The microcode ROM and PLA extraction

`docs/V20BITS.TXT` (1028 × 29-bit micro-words, 257 match patterns),
`docs/V20UC.TXT` (its 1,285-line disassembly), `docs/V20UCDIS.PAS` (the
normative encoding spec, as an executable Pascal disassembler),
`docs/v20_microcode_04.xlsx`, and the PLA transcriptions
(`docs/pla_2.txt`, `pla_3.txt`, `pla3_outputs.txt`, `pla4.txt`) with their die
photographs (`docs/pla_1.jpg` … `pla_5.jpg`) are **third-party die
transcriptions**, not this project's work.

The public origin of that extraction is the VCFed thread
[**"The NEC V20 Microcode ROM"**](https://forum.vcfed.org/index.php?threads/the-nec-v20-microcode-rom.1254770/):

- **GloriousCow** — started the thread, extracted the
  microcode bit array from the ROM photographs using a convolutional neural
  network, and published the corrected word extraction and the
  field-decoding spreadsheet.
- **InfoSecDJ** — decap and high-resolution die imaging, through their
  commissioning service at [siliconpr0n.org](https://siliconpr0n.org).
- **dreNorteR** — opcode-mapping analysis and the initial decoding of the
  activation PLA and the microcode fields.

Additional die-level and functional context:

- **dev-zzo**, [*"NEC V20 PLA"*](https://dev-zzo.github.io/blarg/2025/10/06/nec-v20-pla.html)
  (2025-10-06) — the electrical analysis of the nine on-die PLA structures.
  Used for implementation context only; it assigns no functional meaning and
  publishes no dimension table.
- **Ken Shirriff**, [*"The Group Decode ROM in the Intel 8086"*](https://www.righto.com/2023/05/8086-processor-group-decode-rom.html) —
  used as a **hypothesis source only** for `pla_3`'s column semantics. Ten of
  `pla_3`'s fourteen columns are recognisably the same signals, but every V20
  column is proven against V20 metadata, never asserted by analogy. Also
  [*"Silicon reverse engineering: the 8086 flag circuitry"*](http://www.righto.com/2023/02/silicon-reverse-engineering-intel-8086.html)
  and [*"Reverse-engineering the 8086's ALU"*](http://www.righto.com/2020/08/reverse-engineering-8086s.html),
  used as structural analogy for the flag-race work.

### The test-suite format and the V20 golden suite

- **SingleStepTests / V20** — [github.com/SingleStepTests/v20](https://github.com/SingleStepTests/v20),
  by **Daniel Balsom**. Generated with the Arduino8088 v1.1 hardware interface
  and the MartyPC emulator, from a *"NEC JAPAN V20 8902NX D70108C-8 1984"* in
  maximum mode with an Intel 8288. **Version 1.0.2/1.0.3, `syntax_version` 2.**

  This project uses it two ways: its **schema** is the format every suite here
  is emitted in (extended for the V30's 16-bit bus per the 8086 suite's
  precedent), and the **suite itself** is vendored at `tests/v30/v20suite/` and
  run as a 3,125,000-case functional gate. Format notes and the full schema
  analysis are in `docs/notes/singlesteptests_v20.md`; the vendored
  `metadata.toml` retains its upstream authorship.

- **SingleStepTests / 8086** — [github.com/SingleStepTests/8086](https://github.com/SingleStepTests/8086) —
  the precedent for extending the schema to a 16-bit bus.

- **arduinoX86 / Arduino8088** — [github.com/dbalsom/arduinox86](https://github.com/dbalsom/arduinox86),
  by **Daniel Balsom**. Its register load/store stub methodology — how you get a
  CPU with no debug port into and out of a known architectural state — is the
  direct ancestor of this project's state injection/extraction. Analysed in
  `docs/notes/arduinox86.md`; background at
  [martypc.blogspot.com](https://martypc.blogspot.com/2023/06/hardware-validating-emulator.html).

- **VirtualXT / pi8088** — [github.com/andreas-jonsson/virtualxt](https://github.com/andreas-jonsson/virtualxt/tree/develop/tools/validator/pi8088) —
  prior art for hardware CPU validation.

### Emulation and documentation references

- **MAME** — [github.com/mamedev/mame](https://github.com/mamedev/mame),
  `src/devices/cpu/nec` — mined as a behavioural reference
  (`docs/notes/mame_necv.md`).
- **MartyPC** — [github.com/dbalsom/martypc](https://github.com/dbalsom/martypc) —
  the emulator behind the V20 suite's generation.
- **bitsavers.org** — the vendor documentation in `docs/raw/`: the 1991 NEC
  16-bit V-Series Microprocessor Data Book, the V20/V30 User's Manual (Oct 86),
  the 1997 16-bit V-Series User's Manual, and Intel's 8086 Family User's Manual
  (Oct 79) for the max-mode bus protocol and queue-status semantics.
- **MiSTer** — the DE10-Nano framework (`hdl/sys/`) this harness is built in.

