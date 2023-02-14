#!/bin/bash
# Generates MCU disassembled code for reference

f9dasm -offset 0xF000 a78-01.17 -6801 -out mcu.asm
