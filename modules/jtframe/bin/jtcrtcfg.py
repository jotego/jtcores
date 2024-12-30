# Script for choosing settings on Analogizer
# Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
# Version: 1.0
# Date: 10-6-2024

import binascii
import argparse
import glob
import os

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

def create_in_release(do=False, filename="crtcfg.bin", find="jtcores/release", common="/pocket/raw/Assets/jtpatreon/common/"):
    if do:
        search = os.path.join(os.path.expanduser("~"),f'**/{find}')
        rel = glob.glob(search, recursive=True)
        if rel:
            releasepath = rel[0]
        else:
            releasepath = None
            print("Release folder could not be found")
            return filename
        if not os.path.exists(releasepath+common): os.makedirs(releasepath+common)
        finalpath = releasepath+common+filename
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

def user_options(records, w_len=32, filename="test.bin",filename2=None):
    final_num = ""
    files = [filename, filename2]
    if filename==filename2: files[1] = None
    for sel in records:
        sel_input = sel.get_input() # input(sel.options).lower()
        #Add options to Binary string
        for it in sel.dict:
            for s in sel.dict[it]:
                final_num += str(s)
    #Rellenar valores faltantes con 0 a la derecha
    if len(final_num) < w_len: final_num += "0"*(w_len-len(final_num))
    hex_str = hex(int(final_num,2))[2:].zfill(w_len // 4)

    #print(hex_str,len(final_num), final_num)
    # Guardar los datos binarios en un archivo
    for f in files:
        if f==None: continue
        with open(f, 'wb') as binary_file:
            binary_file.write(binascii.unhexlify(hex_str))

parser = argparse.ArgumentParser()
parser.add_argument('--sd', action='store_true')
parser.add_argument('--release', action='store_true')
args = parser.parse_args()
sd   = False
if args.sd==True: sd = args.sd
rel   = False
if args.release==True: rel = args.release
# Crear el objeto 'crt' de la clase 'OptionType'
crt = OptionType()

crt.options ="""
Please, select your prefered Video Option.
For example: A for RGB video

Letter | Option
-------|--------------------------------------------|
   A   | RBGS       (SCART)                         |
   B   | RGsB                                       |
   C   | YPbPr      (Component video)               |
   D   | Y/C NTSC   (SVideo, Composite video)       |
   E   | Y/C PAL    (SVideo, Composite video)       |
   F   | Scandoubler RGBHV (SCANLINES  0%)          |
   G   | Scandoubler RGBHV (SCANLINES 25%)          |
   H   | Scandoubler RGBHV (SCANLINES 50%)          |
   I   | Scandoubler RGBHV (SCANLINES 75%)          |
   X   | Disable Analog Video                       |
----------------------------------------------------|

Your selection:    """

crt.dict = {
    "a" : [0],    "b" : [0],
    "c" : [0],    "k" : [0],
    "l" : [0],    "u" : [0],
    "d" : [0],    "i" : [0],
    "j" : [0],    "h" : [0],
    "g" : [0],    "f" : [0],
}
crt.replace = {"f": "af",  "h": "afh",
               "g": "afg", "i": "afgh",
               "e": "akl", "d": "ak" ,
               "c": "acj", "b": "abj",
               "x": "",    "a": "ad"}

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
snac.replace = {"a": "", "e":"eb", "f":"ec","d":"cb"}

filepath  = create_in_pocket(do=sd)
filepath2 = create_in_release(do=rel)
user_options([crt, snac],filename=filepath, filename2=filepath2)
