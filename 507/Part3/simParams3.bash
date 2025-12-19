#!/usr/bin/bash

# script to generate the params.sv file based on the command line parameters, 
# compile the code and testbench, and run simulation.
# usage: ./simParams3 [INW] [R] [C] [MAXK] [TVALID_PROB] [GUI]
#    where you will replace [INW] [R] [C] [MAXK] and [TVALID_PROB] with the 
#    desired value of those parameters.
#    Remember that if TVALID_PROB = 0, the testbench will randomize it.

#    if [GUI] is 0, the simulation will run in waveform mode. If [GUI] is 1, it will 
#    run QuestaSim in GUI mode
# example: for INW=16, R=7, C=6, MAXK=5 with random TVALID_PROB, simulating at the 
# command line only, run: 
#        ./simParams3 16 7 6 5 0 0

# If you want to run in GUI mode, you should run with & at the end, like
#        ./simParams3 16 7 6 5 0 1 &

# Note that this will compile all .sv files in your directory. If instead you
# only want to compile some of them, you can edit this or compile directly from the command line.

if [ $# -ne 6 ]; then
    echo "ERROR: incorrect number of parameters given."
    echo "Usage: ./simParams3 [INW] [R] [C] [MAXK] [TVALID_PROB] [GUI]"
    echo "See comments in simParams3 file for more information"
else
    ./genParams3 $1 $2 $3 $4 $5
    vlog -64 +acc *.sv
    if [[ $6 -eq 0 ]]; then
        vsim -64 -sv_seed random -c input_mems_tb -do "run -all; quit"
    else 
        vsim -64 -sv_seed random input_mems_tb
    fi
fi