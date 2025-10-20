#!/usr/bin/bash

# script to generate the params.sv file based on the command line parameters, 
# compile the code and testbench, and run simulation.
# usage: ./simParams2 [OUTW] [DEPTH] [IN_TVALID_PROB] [OUT_TREADY_PROB] [GUI]
#    where you will replace [OUTW] [DEPTH] [IN_TVALID_PROB] and [OUT_TREADY_PROB]
#    with the desired value of those parameters.
#    Remember, if IN_TVALID_PROB or OUT_TREADY_PROB are 0, the simulator will randomize them

#    if [GUI] is 0, the simulation will run in waveform mode. If [GUI] is 1, it will 
#    run QuestaSim in GUI mode
# example: for OUTW=32, DEPTH=33, with random IN_TVALID_PROB and OUT_TREADY_PROB,
#          simulating at the command line only, run: 
#              ./simParams2 32 33 0 0 0

# If you want to run in GUI mode, you should run with & at the end, like
#        ./simParams2 32 33 0 0 1 &

# Note that this will compile all .sv files in your directory. If instead you
# only want to compile some of them, you can edit this or compile directly from the command line.

if [ $# -ne 5 ]; then
    echo "ERROR: incorrect number of parameters given."
    echo "Usage: ./simParams2 [OUTW] [DEPTH] [IN_TVALID_PROB] [OUT_TREADY_PROB] [GUI]"
    echo "See comments in simParams2 file for more information"
else
    ./genParams2 $1 $2 $3 $4
    vlog -64 +acc *.sv 
    if [[ $5 -eq 0 ]]; then
        vsim -64 -sv_seed random -c fifo_out_tb -do "run -all; quit"
    else 
        vsim -64 -sv_seed random fifo_out_tb
    fi
fi