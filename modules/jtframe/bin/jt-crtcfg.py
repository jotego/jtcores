    # Script for choosing settings on Analogizer
    # Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    # Version: 1.0
    # Date: 10-6-2024

import binascii
import argparse
import glob
import os
parser = argparse.ArgumentParser()
parser.add_argument('--sd', action='store_true')
args = parser.parse_args()
sd   = False
if args.sd==True: sd = args.sd

def find_sd_card_path(sd_card_name):
    sd_path = glob.glob(f'/media/*/{sd_card_name}')
    if sd_path:
        return sd_path[0]
    else:
        return None

def create_in_pocket(do=False, filename="crtcfg.bin", find="POCKET", common="/Assets/jtpatreon/common/"):
    if do:
        pocketpath = find_sd_card_path(find)
        if pocketpath == None:
            print("No SD card detected. File will be created in current path")
            return filename
        if not os.path.exists(pocketpath+common): os.makedirs(pocketpath+common)
        finalpath = pocketpath+common+filename
        return finalpath
    return filename

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
   C   | Set YPbPr output                           |
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
# filename = "crtcfg.bin"
# commonpath = "/Assets/jtpatreon/common/"

filepath = create_in_pocket(do=sd)

user_options([crt, snac],filename=filepath)
