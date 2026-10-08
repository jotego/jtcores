#!/bin/bash
# enters service menu
# Convert test_obj.inputs to a .cab file to enter the object test.
jtsim -inputs sim_inputs.cab -setname 1943 -q -dipsw ff78 $*
