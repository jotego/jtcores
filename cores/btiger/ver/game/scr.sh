#!/bin/bash


go.sh -d NOMAIN -d NOSOUND -d NOMCU -d NOCHAR \
    -d JTCHAR_LOWER_SIMFILE=',.simfile("scr0.bin")' \
    -d JTCHAR_UPPER_SIMFILE=',.simfile("scr1.bin")' \
    -video 2 -w