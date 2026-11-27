# Seicro CPU compatibility

The native MC6802 core's documented timing inventory covers 197 opcodes;
undefined encodings have no assigned behavior here. Seicro adds a
core-local opcode adapter and profile for the MAME-observed BRN `$21`, direct
JSR `$9D`, and NSC8105 extensions. The normal Seicross and Sector Zone sets use
the NSC8105 permutation; `sectrzont` selects native MC6802 behavior. Frisky Tom
set `friskytb` uses the gated raw `$FC` compatibility dispatch.

The adapter does not whitelist standard opcodes or substitute a fallback for
undefined bytes. It passes standard bytes through, permutes NSC opcode bits,
and maps standard Frisky raw `$FC` to a private extension ID only in that
runtime mode.

The NSC8105 operations are based on MAME 0.289 (`e5a5a102889d6c62f12e39a4db3e950e4f5d6822`), specifically `src/devices/cpu/m6800/m6800.cpp` (`cycles_nsc8105`) and `src/devices/cpu/m6800/6800ops.hxx` (`stx_nsc`, `btst_ix`, `adcx_im`, `addx_ex`); no NSC8105 datasheet or measured silicon timing is available. NSC raw `$FC`
maps to ADDX extended. Its Seicro sequence takes 5 E cycles, while MAME lists
4. The five-cycle sequence uses two address reads, two data reads, and the next
opcode fetch, with one accepted transfer per E phase. This preserves the prior
PR behavior; the extra cycle is a compatibility choice and is not a claim about
the hardware's timing. The directed test checks the result, flags, and five-E
bus sequence.

Frisky raw `$FC` behavior is undocumented in the Motorola manual and MAME
defines no hardware semantics for it. The compatibility test verifies that
only `frisky && !nsc8105` selects the private opcode; it does not establish a
silicon-defined effect or timing.

See [hardware verification](doc/hardware_verification.md) for board timing and
bus details.
