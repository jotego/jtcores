#!/bin/bash
# enters service menu
# use test_obj.inputs as sim_inputs.hex to enter the object test
# cp test_obj.inputs sim_inputs.hex
jtsim -inputs -setname 1943 -q -dipsw ff78 $*
