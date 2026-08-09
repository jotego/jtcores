#!/bin/bash
jtutil sdram
jtsim -inputs coin.cab -video 334 -w 222
mv test.fst coin.fst
mv test.wav coin.wav
