#!/usr/bin/env python3
import sys, os
sys.path.insert(0,'cores/mnymny/sch/gen')
from hier import SHEETS
for name, meta in SHEETS.items():
    path = f'cores/mnymny/sch/{name}.kicad_sch'
    if os.path.exists(path): continue
    txt = ('(kicad_sch\n\t(version 20231120)\n\t(generator "eeschema")\n'
           '\t(generator_version "8.0")\n'
           f'\t(uuid "{meta["filuuid"]}")\n\t(paper "A3")\n'
           '\t(title_block\n\t\t(title "'+meta['title']+'")\n\t\t(date "2026-09-07")\n'
           '\t\t(rev "P82-003/A/M3")\n\t\t(company "JOTEGO")\n'
           '\t\t(comment 1 "Money Money / Jack Rabbit")\n'
           '\t\t(comment 2 "For repair and maintenance - TO DO")\n\t)\n'
           '\t(lib_symbols\n\t)\n)\n')
    open(path,'w').write(txt)
    print('placeholder:', name)
