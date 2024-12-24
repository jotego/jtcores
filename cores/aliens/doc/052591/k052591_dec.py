# Konami 052591 decoder/disassembler
# 2023 furrtek

import sys

lut_in = ["RegA Acc  ", "RegA RegB ", "#0   Acc  ", "#0   RegB ", "#0   RegA ", "I/R RegA ", "I/R Acc", "I/R #0"]
lut_op = ["Add ", "Add ", "Sub ", "OR  ", "AND ", "?   ", "?   ", "?   "]
lut_cc = ["z", "c", "o", "n"]

spaces = [2, 5, 8, 11, 14, 15, 23, 26, 28, 31, 33]

def bit(n, c):
	return int(binstr[35 - n]) == c
	
def pad(s, n):
	while (len(s) < n):
		s += " "
	return s

fn_in = sys.argv[1]
fn_out = fn_in + ".txt"

with open(fn_in, "rb") as f:
	iram = f.read()

f = open(fn_out, "w")

f.write(fn_in + "\n")
f.write("              33 33 332 22 222 22221111 1 111 11               (Imm and PC values are in hex)\n")
f.write("Addr          54 32 109 87 654 32109876 5 432 109 876 543 210  ALUA ALUB Op  s Dst  S/R I Jump     RamU Ext      Ctrl                   Code\n")

for a in range(0, 64):
	dispstr = "{:02x}: ".format(a)

	# Bytes to binary word with spacing
	i = a * 5
	byte = iram[i + 4] & 15
	hexstr = "{:01x}".format(byte)	# First nibble
	binstr = "{:04b}".format(byte)
	for b in range(0, 4):
		byte = iram[i + 3 - b]
		hexstr += "{:02x}".format(byte)
		binstr += "{:08b}".format(byte)

	dispstr += (hexstr + " ")
	binstr_sp = binstr
	for space in spaces:
		index = 35 - space
		binstr_sp = binstr_sp[:index] + ' ' + binstr_sp[index:]
	dispstr += (binstr_sp + "  ")


	rega = "r{:01d}".format((iram[i + 1] >> 1) & 7)
	regb = "r{:01d}".format((iram[i + 1] >> 4) & 7)

	sr_shift = bit(33, 1)
	sr = bit(8, 1)
	sr_left = bit(7, 1)

	imm = ((iram[i + 3] & 15) << 8) + iram[i + 2]
	if bit(28, 1):
		imm = -imm	# Sign bit

	# IR31 IR30
	#  0    0		Update ext RAM data with ext_value LSB
	#  0    1		Update ext RAM data with ext_value MSB
	#  1    0		Update ext RAM address with ext_value
	#  1    1		NOOP

	ext_update = ""
	if bit(31, 0):
		# Update ext RAM data
		if bit(30, 1):
			ext_update = "D=val(U)"
		else:
			ext_update = "D=val(L)"
	else:
		if bit(30, 0):
			ext_update = "A=val"

	ext_value_rega = bit(8, 0) and bit(7, 1) and bit(6, 0)	# Otherwise ALU
	ext_update = ext_update.replace("val", "RegA" if ext_value_rega else "ALU")

	acc_update = not (bit(8, 0) and bit(7, 1)) and bit(6, 0)

	# IR35 IR15
	#  0    0	ALU A pre-mux is RAM data, latch RAM data byte as ALU A high byte
	#  0    1   ALU A pre-mux is RAM data
	#  1    0   ALU A pre-mux is RAM data, MSB is zero
	#  1    1   ALU A pre-mux is immediate

	size_word = True
	ram_msb = False

	if bit(35, 1) and bit(15, 1):
		imm_ram = pad("#{:x}".format(imm), 4)	# Immediate
	else:
		imm_ram = "Ram "
		if bit(15, 0):
			if bit(35, 1):
				size_word = False
			else:
				ram_msb = True

	# IR15=0: Set ext RAM control levels for next cycle with IR28 (/OE) and IR27 (/WE)
	ext_set = False
	if bit(15, 0):
		ext_set = True
		ext_next_oe = bit(28, 1)
		ext_next_we = bit(27, 1)

	# IR29=0: Apply previously set levels to ext RAM control pins
	ext_apply = bit(29, 0)

	# IR34 IR15
	#  0    0
	#  0    1	Set OUT0 pin to IR16 (immediate bit 0)
	#  1    0	ALU carry in = 1 when IR33=1 or IR32=0
	#  1    1

	# PIN_OUT0 is set with IR16 when IR15=1 and IR34=0
	out0_set = bit(15, 1) and bit(34, 0)
	out0_level = bit(16, 1)

	# ALU inputs
	alu_incode = iram[i] & 7
	alu_in = lut_in[alu_incode]
	alu_in = alu_in.replace("I/R", imm_ram)
	alu_in = alu_in.replace("RegA", rega + "  ")
	alu_in = alu_in.replace("RegB", regb + "  ")

	# ALU op
	alu_opcode = (iram[i] >> 3) & 7
	alu_op = lut_op[alu_opcode]

	# Destination
	if bit(7, 1) or bit(8, 1):
		dest = regb
	else:
		dest = ""

	# Increment
	if (bit(32, 0) or bit(33, 1)):
		# L59 high
		N68_next = False
		inc = bit(34, 1) and bit(15, 0)
	else:
		# L59 low
		N68_next = alu_neg	# TODO
		inc = bit(3, 1) or N68_next

	# IR15=1: No jump, continue to next instruction

	# IR26 IR25 IR24 IR15
	#  x    x    x    1   N77=0 N74=1	Next

	#  x    1    0    x   N77=0
	#  0    1    1    x   N77=0
	#  0    0    x    0   N77=CC
	#  1    0    x    0   N77=1
	#  1    1    1    0   N77=1

	#  x    1    1    x   N74=1
	#  0    0    x    0   N74=!CC
	#  0    1    0    0   N74=!CC
	#  1    0    x    0   N74=0
	#  1    1    0    0   N74=0

	# Next PC is:
    # N77 N74
	#  0   0  Jump-back
	#  0   1  Next
	#  1   0  Imm
	#  1   1  Initial PC

	# With IR15=0:
	#     N77 N74
	# 000 CC  !CC  Next/Call Imm
	# 001 CC  !CC  Next/Jump Imm
	# 010 0   !CC  Next/Ret
	# 011 0   1	   Next
	# 100 1   0    Call Imm
	# 101 1   0    Jump Imm
	# 110 0   0    Ret
	# 111 1   1    Initial PC

	if bit(15, 1):
		jump = ""
	else:
		if bit(26, 1):
			if bit(25, 1):
				if bit(24, 1):
					jump = "JP  Init"
				else:
					jump = "RET"
			else:
				if bit(24, 1):
					jump = "JP  imm"
				else:
					jump = "CALL imm"
		else:
			if bit(25, 1):
				if bit(24, 1):
					jump = ""
				else:
					jump = "RET cc"
			else:
				if bit(24, 1):
					jump = "JP  cc,imm"
				else:
					jump = "CALL cc,imm"

	cc = lut_cc[(iram[i + 2] >> 6) & 3]
	jump = jump.replace("cc", cc)

	addr = iram[i + 2] & 0x3F
	jump = jump.replace("imm", "{:02x}".format(addr))


	dispstr += pad(alu_in, 10)
	dispstr += pad(alu_op, 4)
	dispstr += pad("W" if size_word else "b", 2)
	dispstr += pad(dest, 3)
	dispstr += pad("A" if acc_update else " ", 2)

	srstr = ""
	if sr:
		sr_char = "<" if sr_left else ">"
		srstr = sr_char * (2 if sr_shift else 3)
	dispstr += pad(srstr, 4)
	
	dispstr += pad("+" if inc else "", 2)
	dispstr += pad(jump, 9)
	
	dispstr += pad("Set" if ram_msb else "", 5)

	dispstr += pad(ext_update, 9)

	ctrlstr = ""
	if ext_set:
		ctrlstr = "OE=" + ("1" if ext_next_oe else "0")
		ctrlstr += (" WE=" + ("1" if ext_next_we else "0"))
	if ext_apply:
		ctrlstr += " Apply"
	dispstr += pad(ctrlstr, 16)

	dispstr += pad("OUT0=" + ("1" if out0_level else "0") if out0_set else "", 7)

	# Attempt decoding some instructions to assembly-like code
	instr = ""
	mnemo = ""
	deststr = ""
	srcstr = ""

	if acc_update:
		deststr += "A"
	if dest:
		deststr += (("," if deststr != "" else "") + dest)

	if bit(31, 1) and bit(30, 0):
		# Update ext RAM address
		deststr += (("," if deststr != "" else "") + "ExtAddr")
	elif bit(31, 0):
		# Update ext RAM data
		if bit(30, 1):
			deststr += (("," if deststr != "" else "") + "ExtDataU")
		else:
			deststr += (("," if deststr != "" else "") + "ExtDataL")

	if ram_msb:
		instr = "mov.b ExtMSB,[Ram]"
		
	if iram[i] & 7 == 2:
		regx = "A"
	elif iram[i] & 7 == 3:
		regx = regb
	elif iram[i] & 7 == 4:
		regx = rega
	else:
		regx = ""

	if bit(35, 1) and bit(15, 1):
		imm_ram = ",#{:x}".format(imm)
	else:
		imm_ram = ",[Ram]"

	if alu_incode == 0:	# Rega, Acc
		srcstr = "," + rega + ",A"
	elif alu_incode == 1:	# Rega, RegB
		srcstr = "," + rega + "," + regb
	elif alu_incode == 2 or alu_incode == 3 or alu_incode == 4:	# #0, RegX
		srcstr = "," + regx
	elif alu_incode == 5:	# I/R, rega
		srcstr = imm_ram + "," + rega
	elif alu_incode == 6:	# I/R, Acc
		srcstr = imm_ram + ",A"
	elif alu_incode == 7:	# I/R, #0
		srcstr = imm_ram
	if inc:
		srcstr += ",#1"

	if alu_opcode == 0 or alu_opcode == 1:
		mnemo = "add"	# ALU op is Add
	elif alu_opcode == 2:
		mnemo = "sub"	# ALU op is Sub
	elif alu_opcode == 3:
		# ALU op is OR
		if alu_incode == 2 or alu_incode == 3 or alu_incode == 4 or alu_incode == 7:
			mnemo = "mov"	# One of the ALU inputs is #0, we have an immediate or RAM load
		else:
			mnemo = " or"	# Both ALU inputs can be non-zero, we have a OR
	elif alu_opcode == 4:
		mnemo = "and"	# ALU op is AND
	else:
		mnemo = "???"	# ALU op is unknown

	mnemo += (".w " if size_word else ".b ")

	if instr != "":
		instr = pad(instr, 22)
	if deststr == "":
		deststr = "x"

	if mnemo != "":
		instr += pad(mnemo + deststr + srcstr, 22)
	if jump != "":
		instr += jump

	dispstr += instr

	f.write(dispstr + "\n")

print("Wrote " + fn_out)

f.close()
