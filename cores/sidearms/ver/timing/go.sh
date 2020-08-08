#!/bin/bash

iverilog test.v -o sim && sim -lxt
