# TMS34010 bring-up opcode catalog

The PC and every memory address below are **bit addresses**. An instruction
word occupies 16 bits, so fetching one word advances PC by `0x10`. The reset
vector is a 32-bit bit address read at `0xFFFF_FFE0` (User's Guide §8.8);
a fresh test starts at the vector's value, not at address zero. The initial
status register is `0x0000_0010` (FS0=16, N/C/Z/V clear; §5.4).

The primary references are the 1988 TI
[*TMS34010 User's Guide* (SPVU001A)](https://www.bitsavers.org/components/ti/TMS340xx/1988_TI_TMS34010_Users_Guide.pdf),
with page numbers below. The repository's
`modules/tms34010/docs/instruction_coverage.md` cross-checks the opcodes
against assembled TI examples and the mature decoder. The separately supplied
`/gdrive/jotego/arcade/components/tms34010.pdf` is a 60-page scanned data
sheet: `pdftotext` does not expose its instruction pages. It should not be
mistaken for the User's Guide.

`R=0` selects the A register file and `R=1` selects B. `S` and `D` are
four-bit register indexes. Extension words are fetched in address order.

| Instruction | First word and extensions | Effect and flags | SPVU001A |
| --- | --- | --- | --- |
| NOP | `0300` | No change | 12-170 |
| MOVI IW, Rd | `09C0 \| R<<4 \| D`, signed 16-bit immediate | Sign extend to Rd; N/Z set from result, V=0, C preserved | 12-159 |
| MOVI IL, Rd | `09E0 \| R<<4 \| D`, low 16, high 16 | 32-bit value to Rd; N/Z set, V=0, C preserved | 12-160 |
| MOVK K,Rd | `1800 \| (K&31)<<5 \| R<<4 \| D` | Rd=K; encoded K=0 means **32**; flags unchanged | 12-161 |
| ADDK K,Rd | `1000 \| (K&31)<<5 \| R<<4 \| D` | Rd+=K; encoded K=0 means 32; N/C/Z/V set | 12-40 |
| SUBK K,Rd | `1400 \| (K&31)<<5 \| R<<4 \| D` | Rd-=K; C is borrow; N/C/Z/V set | 12-251 |
| MOVE Rs,Rd | `4C00 \| M<<9 \| S<<5 \| R<<4 \| D` | Full 32-bit copy; N/Z set, V=0, C preserved | 12-126 |
| ADD Rs,Rd | `4000 \| S<<5 \| R<<4 \| D` | Rd=Rd+Rs; N/C/Z/V set | A-14 |
| SUB Rs,Rd | `4400 \| S<<5 \| R<<4 \| D` | Rd=Rd-Rs; C is borrow; N/C/Z/V set | A-14 |
| AND/ANDN/OR/XOR Rs,Rd | `5000`/`5200`/`5400`/`5600` `\| S<<5 \| R<<4 \| D` | Full result to Rd; **only Z** changes | 12-42/44/172/255 |
| SETC | `0DE0` | C=1; other flags unchanged | A-14 |
| JRcc short | `C000 \| cc<<8 \| displacement8` | PC=PC' + signed displacement ×16 when condition holds; flags unchanged | 12-96, Table 12-8 |
| JUMP Rs | `0160 \| R<<4 \| S` | PC=Rs with low four bits cleared; flags unchanged | 12-98 |

For MOVE, `M=0` means both registers are in file R; `M=1` means the source is
in file R and the destination is in the other file. JR condition `0` is
unconditional and condition `A` is EQ (Z=1). Short displacements `00` and
`80` select the long and absolute forms, so do not use them as short offsets.
`PC'` is the PC after fetching the branch opcode. The branch instruction
itself does not change status.

The A15 and B15 register names refer to the same physical stack pointer
(User's Guide §5.1.3). The suite checks that a write through either name is
visible through the other.

The initial tests use the listed operations and assert architectural state
after instruction retirement. They intentionally avoid timing assertions:
microcode and memory wait states can change cycle counts without changing
the visible result. A reset-vector fetch test checks the first retired PC and
status; separate programs cover sign extension, arithmetic, both register
files, cross-file MOVE, conditional branch decisions, JUMP alignment, flags at
arithmetic boundaries, logical flag preservation, reserved-opcode fault, and
a memory acknowledgement while clock enable is paused.

Run `modules/jttms10/ver/run.sh` from the repository root (or any directory).
It generates jtframe microcode, compiles the RTL with Icarus Verilog, and runs
every case in `ver/tests.yaml`. `--case NAME` selects one case. The YAML is
the source for both the program words and retire assertions; `vectors.py`
can also export `.mem`, `.svh`, and `.json` artifacts for another bench.
