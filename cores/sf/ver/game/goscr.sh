#!/bin/bash
# SF doesn't have scroll memory, just scroll positions
# Scene  | FG  | BG
# Start  | 100   | 0

go.sh -d NOMAIN -d NOSOUND -d NOCHAR -d NOOBJ -d GRAY -d NOMCU \
    -deep -video 2 $*
#go.sh -d NOMAIN -d NOCHAR -d NOOBJ -d GRAY -deep -video 2