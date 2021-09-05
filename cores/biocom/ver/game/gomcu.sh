#/bin/bash
cp sim_inputs_game.hex sim_inputs.hex || exit $?
go.sh -nosnd -video 190 -w -d DUMP_START=139 -inputs
