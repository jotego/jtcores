#!/usr/bin/env python3
"""Root landing sheet: one hierarchical sheet box per manual page."""
import sys
sys.path.insert(0,'cores/mnymny/sch/gen')
from kisch import uid, SN
from hier import ROOT, SHEETS

W,H = 63.5, 25.4   # sheet box size
COLS = 3
out=['(kicad_sch\n\t(version 20231120)\n\t(generator "eeschema")\n\t(generator_version "8.0")\n']
out.append(f'\t(uuid "{ROOT}")\n\t(paper "A3")\n')
out.append('\t(title_block\n\t\t(title "MONEY MONEY / JACK RABBIT - Zaccaria 1B11140/41/42/47")\n'
           '\t\t(date "2026-09-07")\n\t\t(rev "17.5.1983 manual")\n\t\t(company "JOTEGO")\n'
           '\t\t(comment 1 "For repair and maintenance")\n\t)\n')
out.append('\t(lib_symbols\n\t)\n')
for i,(name,meta) in enumerate(SHEETS.items()):
    x = SN(30 + (i%COLS)*(W+25.4)); y = SN(30 + (i//COLS)*(H+20.32))
    out.append(f'''\t(sheet
\t\t(at {x} {y})
\t\t(size {W} {H})
\t\t(fields_autoplaced yes)
\t\t(stroke
\t\t\t(width 0.1524)
\t\t\t(type solid)
\t\t)
\t\t(fill
\t\t\t(color 0 0 0 0.0000)
\t\t)
\t\t(uuid "{meta['symuuid']}")
\t\t(property "Sheetname" "{name}"
\t\t\t(at {x} {SN(y-0.8)} 0)
\t\t\t(effects
\t\t\t\t(font
\t\t\t\t\t(size 1.27 1.27)
\t\t\t\t)
\t\t\t\t(justify left bottom)
\t\t\t)
\t\t)
\t\t(property "Sheetfile" "{name}.kicad_sch"
\t\t\t(at {x} {SN(y+H+0.8)} 0)
\t\t\t(effects
\t\t\t\t(font
\t\t\t\t\t(size 1.27 1.27)
\t\t\t\t)
\t\t\t\t(justify left top)
\t\t\t)
\t\t)
\t\t(instances
\t\t\t(project "mnymny"
\t\t\t\t(path "/{ROOT}"
\t\t\t\t\t(page "{meta['page']}")
\t\t\t\t)
\t\t\t)
\t\t)
\t)
''')
out.append('\t(sheet_instances\n\t\t(path "/"\n\t\t\t(page "1")\n\t\t)\n\t)\n)\n')
txt=''.join(out)
assert txt.count('(')==txt.count(')')
open('cores/mnymny/sch/mnymny.kicad_sch','w').write(txt)
print("root written,",len(SHEETS),"sheets")
