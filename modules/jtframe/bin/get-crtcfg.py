    # Script for choosing settings on Analogizer
    # Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    # Version: 1.0
    # Date: 10-6-2024

import binascii

class OptionType:
    def __init__(self):
        self.options = ""
        self.dict = {}
        self.replace = {}

def user_options(records, w_len=32, filename="test.bin"):
    final_num = ""
    for sel in records:
        nf = "" #Options not found
        sel_input = input(sel.options).lower()
        #Replace unwanted values and evaluate selection
        if sel.replace:
            for r in sel.replace: sel_input = sel_input.replace( r,sel.replace[r] )
        for let in set(sel_input):
            if let not in sel.dict or let=="u":  nf += let
            else:                                sel.dict[let][0] += 1
        if nf: print(f"Sorry, could not find following options: '{nf.upper()}'. Inputs ignored\n")
        #Add options to Binary string
        for it in sel.dict:
            for s in sel.dict[it]:
                final_num += str(s)

    #Rellenar valores faltantes con 0 a la derecha
    if len(final_num) < w_len: final_num += "0"*(w_len-len(final_num))
    hex_str = hex(int(final_num,2))[2:]

    #print(hex_str,len(final_num), final_num)
    # Guardar los datos binarios en un archivo
    with open(filename, 'wb') as binary_file:
        binary_file.write(binascii.unhexlify(hex_str))


# Crear el objeto 'crt' de la clase 'OptionType'
crt = OptionType()

crt.options ="""
Please, select all options that apply by typing a string of the corresponding letters in the following table.
For example: ADEG

Letter | Option
-------|--------------------------------------------|
   A   | Enable Analogic Video Output               |
   B   | Bypass Video (cancels other options)       |
   C   | Set YPbPr outout                           |
   D   | Enable Composite Sync                      |
   E   | Scandoubler Enabler                        |
   F   | Scanlines mode 1                           |
   G   | Scanlines mode 2                           |
   H   | Scanlines mode 3                           |
   I   | Enable Bandwidth effect                    |
   J   | Enable Blendig effect                      |
----------------------------------------------------|

Your selection:   """

crt.dict = {
    "a" : [0],    "b" : [0],
    "c" : [0],    "u" : [0,0,0],
    "d" : [0],    "i" : [0],
    "j" : [0],    "g" : [0],
    "f" : [0],    "e" : [0],
}
crt.replace = {"h": "fg",}


user_options([crt],filename="crtcfg.bin")


"""
Bit | Use                                        |
----|--------------------------------------------|
11  | Enable Analogic Video Output               |
10  | Bypass Video Mist Module and direct assign |
 9  | Set YPbPr outout                           |
8-6 | Unused                                     |
 5  | Enable Composite Sync                      |
 4  | Enable Bandwidth effect                    |
 3  | Enable Blendig effect                      |
1,2 | Scanlines mode selection                   |
 0  | Scandoubler Enabler                        |"""