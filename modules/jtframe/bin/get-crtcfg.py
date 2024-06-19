    # Script for choosing settings on Analogizer
    # Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    # Version: 1.0
    # Date: 10-6-2024

import binascii

class OptionType:
    def __init__(self, exp1=True, skp=["u"]):
        self.options = ""
        self.dict = {}
        self.replace = {}
        self.expect1 = exp1
        self.skip = ''.join(skp)
    def get_input(self):
        inp = input(self.options).lower()
        nf  = ""
        if self.expect1 and len(inp)>1:
            print(f"\nExpected input lenght: 1\nInput lenght found: {len(inp)}\nTry again.")
            return self.get_input()
        if self.replace:
            for r in self.replace: inp = inp.replace( r,self.replace[r] )
        for let in set(inp):
            if let not in self.dict or let in self.skip:  nf += let
            else:                                         self.dict[let][0] += 1
        if nf: print(f"Sorry, could not find following options: '{nf.upper()}'. Inputs ignored\n")
        return  inp

def user_options(records, w_len=32, filename="test.bin"):
    final_num = ""
    for sel in records:
        sel_input = sel.get_input() # input(sel.options).lower()
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
crt = OptionType(exp1=False)

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

Your selection:    """

crt.dict = {
    "a" : [0],    "b" : [0],
    "c" : [0],    "u" : [0,0,0],
    "d" : [0],    "i" : [0],
    "j" : [0],    "g" : [0],
    "f" : [0],    "e" : [0],
}
crt.replace = {"h": "fg",}

snac = OptionType()

snac.options = """
Please, select the option corresponding to your controller.

Letter | Option
-------|--------------------------------------------|
   A   | None                                       |
   B   | DB15 Normal                                |
   C   | NES                                        |
   D   | SNES                                       |
   E   | PCE 2BTN/6BTN                              |
   F   | PCE Multitap                               |
----------------------------------------------------|

Your selection:    """

snac.dict = {
    "u" : [0,0,0],
    "a" : [0],
    "f" : [0],
    "e" : [0],
    "c" : [0],
    "b" : [0],
}
snac.replace = {"a": "", "f":"ec","d":"cb"}

user_options([crt, snac],filename="crtcfg.bin")


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


# nums = ["1234","2413","3142","4321"]

# for x in range(1,5):
#     for y in range(1,5):
#         if x == y: continue
#         xy = str(x)+str(y)
#         f = 0
#         for n in nums:
#             if n.find(xy) >= 0: f+=1
#         if f == 0: print(f"{xy} not found in any block")
#         if f > 1 : print(f"{xy} found {f} times")

