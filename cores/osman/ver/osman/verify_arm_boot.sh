#!/bin/bash
# Diff FPGA ARM fetch stream vs MAME boot trace. The FPGA logs every ROM fetch
# (instruction + literal-pool loads), so MAME's per-instruction PCs must appear
# as an in-order SUBSEQUENCE of the FPGA addresses within a window.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FPGA=${1:-$HERE/../game/osman_arm_fpga.tr}
MAME=${2:-$HERE/traces/arm_boot.tr}
WINDOW=${WINDOW:-64}

# MAME PCs (7-hex, no colon) in order. The "x" prefix forces string context:
# bare hex like 0000E14 is read by awk as 0e14 == 0 (scientific notation), which
# would collapse every <digits>E<digits> address together. Keep it through the
# dedup and the matcher below.
awk -F: '{gsub(/ /,"",$1); print "x" toupper($1)}' "$MAME" | head -1600 > /tmp/mame_pc.txt
# FPGA fetch addrs (7-hex), collapse immediate repeats
awk -F: '{gsub(/ /,"",$1); print "x" toupper($1)}' "$FPGA" | awk '$1!=p{print}{p=$1}' > /tmp/fpga_pc.txt

# An empty file would silently shift awk's FNR==NR file detection -> false OK
[ -s /tmp/fpga_pc.txt ] || { echo "FAIL: FPGA trace is empty: $FPGA"; exit 1; }
[ -s /tmp/mame_pc.txt ] || { echo "FAIL: MAME trace is empty: $MAME"; exit 1; }

awk -v W="$WINDOW" '
  FNR==NR { fpga[FNR]=$1; nf=FNR; next }
  { mame[FNR]=$1; nm=FNR }
  END {
    fi=1
    for(mi=1; mi<=nm; mi++){
      found=0
      for(k=fi; k<=nf && k<fi+W; k++) if(fpga[k]==mame[mi]){ found=1; fi=k+1; break }
      if(!found){
        printf "DIVERGE at MAME line %d: PC %s not found in FPGA[%d..%d]\n", mi, substr(mame[mi],2), fi, fi+W-1
        printf "  MAME context: "; for(j=mi-2;j<=mi+2;j++) if(j>=1&&j<=nm) printf "%s ", substr(mame[j],2); printf "\n"
        printf "  FPGA context: "; for(j=fi;j<fi+8&&j<=nf;j++) printf "%s ", substr(fpga[j],2); printf "\n"
        exit 1
      }
    }
    printf "OK: all %d MAME PCs matched as subsequence (through PC %s)\n", nm, substr(mame[nm],2)
  }
' /tmp/fpga_pc.txt /tmp/mame_pc.txt
