# Konami 052591 PMC

* Role: Custom CPU used for security through obscurity
* Manufacturer: Fujitsu
* Die marking: 660118
* Technology: CMOS gate array
* Used on: Hexion, Thunder Cross, S.P.Y.

Another one of Konami's barely used crazy ideas to attempt thwarting piracy.

The 052591 is a custom 8/16 bit big-endian CISC CPU.
* Eight 16-bit registers and one accumulator
* Single-step shift/rotate
* Call depth: one
* Add/sub and bitwise operations, no mul or div
* Parallel conditional branching based on 4 flags: zero, carry, overflow, and negative
* Access to a max of 8kB 8-bit external memory with independently controllable /OE and /WE lines
* All instructions take one cycle to execute. Accessing 16-bit external data must be done in two steps.

The game's main CPU loads a small program, gives it some data to process, lets it run, and gets interrupted when the job's done.
Hexion has it connected to VRAM instead of dedicated work RAM ?

The program is stored in internal RAM, with a maximum size of 64 36-bit fixed-length instructions.

# Disassembler

Use `k052591_dec.py` to disassemble/decode binary programs.

Row descriptions:
* ALUA ALUB: ALU inputs. # means immediate value.
* Op: ALU operation.
* s: Operation size, byte or Word.
* Dst: Destination.
* S/R: Shift/rotate operation.
* I: Increment (ALU carry in).
* Jump: Branch operation, if any.
* RamU: Load RAM MSB register with current RAM byte
* Ext: External bus operations, if any. A means address bus is set, D means data bus (with Upper/Lower byte indication).
* Ctrl: Control of external bus. If "Apply" isn't mentioned, then the outputs are unchanged.

# Configuration

Access to internal RAM and external data only works when the START pin is low.

The PC is set to DB[5:0] by writing with AB9 high and BK (BANK) low. DB[7] locks(high) / unlocks(low) PC for program loading.
Loading a program is done in groups of 5 bytes, the least-significant one of each instruction first. The last byte of a group only has its lower nibble used, effectively using 36 bits out of 40.
The instruction is stored and the PC is incremented on every 5th byte write.

External data can be loaded and read back when BK is high.
The internal RAM can't be read back. The BK pin has no effect on reads, external RAM will always be selected.

To start the program, the PC must be locked to the entry point by writing `0x80 | entrypoint` with AB9 high and BK low. Then, the START pin must be set.

It's up to the game's main CPU to stop the k052591 by clearing the START pin. Apparently, all programs use the OUT0 general-purpose output pin to signal this.

# Instructions

Some of their bits have a single purpose, others are coded (see `instruction_bits.ods`).
Immediate values are 13-bit signed, encoded in bits IR[28:16]. These are signed extended to 16 bits by the ALU logic. Jumps are always absolute.

The 8-register bank is connected to two operand registers: A and B. These A and B registers may become the ALU's second operand

| Register | Encoding  | Use                                                               |
|:---------|:----------|:------------------------------------------------------------------|
| A        | IR[11:9]  | external address or data (both input and output), any ALU operand |
| B        | IR[14:12] | ALU's operand B input                                             |

# ALU

| IR[35] | IR[15] | Effect |
| ------ | ------ | --------------------------------------------------------------- |
| 0      | 0      | ALU A pre-mux stage is RAM data, latch RAM data in high byte%   |
| 0      | 1      | ALU A pre-mux stage is RAM data                                 |
| 1      | 0      | ALU A pre-mux stage is RAM data, MSB is zero                    |
| 1      | 1      | ALU A pre-mux stage is immediate                                |

%: The ALU first mux stage will be twice the same byte from RAM. This is used to load 16-bit RAM data in two steps.

The ALU inputs are set according to IR[2:0]:
| IR[2:0] | A in    | B in  |
| ------- | ------- | ----- |
| 0       | Reg A   | Acc   |
| 1       | Reg A   | Reg B |
| 2       | 0       | Acc   |
| 3       | 0       | Reg B |
| 4       | 0       | Reg A |
| 5       | Pre-mux | Reg A |
| 6       | Pre-mux | Acc   |
| 7       | Pre-mux | 0     |

The ALU operation is defined by IR[5:3]:
| IR[5:3] | ALU operation   |
| ------- | --------------- |
| 0       | Add ? |
| 1       | Add ? |
| 2       | Subtract        |
| 3       | OR              |
| 4       | AND             |
| 5       | ? |
| 6       | ? |
| 7       | ? |

Internally, IR[5] inverts the ALU output when low, IR[4] inverts ALU B, IR[3] inverts ALU A.
For example, the AND operation has IR[5:3] = 4 = 0b100, performing A&B. The OR operation has IR[5:3] = 3 = 0b011, effectively performing ~(~A&~B).
If IR[5:3] is lower than 3, arithmetic operations are enabled.

The ALU result is written to reg B if IR[8] or IR[7] are set.

| IR[8:6] | Write ALU result to | Rotate/Shift | Direction | EXT bus |
| ------- | ------------------- | ------------ | --------- | ------- |
| 0       | Accumulator         | None         |           | ALU     |
| 1       | None                | None         |           | ALU     |
| 2       | Reg B               | None         |           | Reg A   |
| 3       | Reg B               | None         |           | ALU     |
| 4       | Reg B and Acc       | IR[33]       | Right     | ALU     |
| 5       | Reg B               | IR[33]       | Right     | ALU     |
| 6       | Reg B and Acc       | IR[33]       | Left      | ALU     |
| 7       | Reg B               | IR[33]       | Left      | ALU     |

IR[33] low: Rotate, high: Shift. This might need further testing.
| IR[33:] | Operation | Direction | Destination | Bit inserted                |
| ------- | --------- | --------- | ----------- | --------------------------- |
|         | Shift     | Left      | Register    | Zero                        |
|         | Rotate    | Left      | Register    | Acc's MSB                   |
|         | Shift     | Right     | Register    | N45 (?)                     |
|         | Rotate    | Right     | Register    | ALU's carry-in              |
|         | Shift     | Left      | Acc         | Zero                        |
|         | Rotate    | Left      | Acc         | Inverse of ALU's result MSB |
|         | Shift     | Right     | Acc         | ALU's result LSB            |
|         | Rotate    | Right     | Acc         | ALU's carry-in              |

When the ALU is set to perform an arithmetic operation, its carry input is set when:
* IR[33:32] == 01 and IR[3] = 1.
* IR[33:32] != 01 and IR[34] = 1 and IR[15] = 0.

# I/O

The OUT0 pin is set to IR[16] when IR[15]=1 and IR[34]=0. It's set high after a reset.

| IR[31:30] | Ext RAM busses               |
| --------- | ---------------------------- |
| 0         | Set data with EXT lower byte |
| 1         | Set data with EXT upper byte |
| 2         | Set address with EXT[12:0]   |
| 3         | No change                    |

The EXT bus is Reg A if IR[8:7] == 3'b010, otherwise it's the ALU result. See table above.

A RAM access is performed when IR[29] == 0, whether subsequent operations are reads or writes is decided by latching IR[28] and IR[27] when IR[15] is low:

* IR[28] sets the external RAM /OE output
* IR[27] sets the external RAM /WE output

# Branching

When IR[15] = 0, branching is enabled. Otherwise PC is just incremented.

| IR[26:24] | Branch                                   |
| --------- | ---------------------------------------- |
| 0         | Conditional call, PC = immediate if true |
| 1         | Conditional jump, PC = immediate if true |
| 2         | Conditional return                       |
| 3         | Next                                     |
| 4         | Call, PC = immediate                     |
| 5         | Jump, PC = immediate                     |
| 6         | Return                                   |
| 7         | Restart program at initial PC            |

The condition is set by IR[23:22]:
| IR[23:22] | Condition | Description |
| --------- | --------- | ----------- |
| 0         | Zero      | Set when the ALU result is zero |
| 1         | Carry     | Represents the ALU's result 17th bit |
| 2         | Overflow  | Set when a 2's complement arithmetic operation overflows (like the Z80's O flag) |
| 3         | Negative  | Copy of the ALU's result 16th bit |

The call depth is only 1 (one), meaning that calls can't be nested.

# Schematic

The schematic was traced from the chip's silicon and should represent exactly how it is internally constructed. The svg can be overlaid on the [die picture](https://siliconpr0n.org/map/konami/052591/furrtek_mz/).

![Konami 052591 internal routing](k052591_trace.png)
