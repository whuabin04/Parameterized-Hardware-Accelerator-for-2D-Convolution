#!/usr/bin/bash

# script to generate the params.sv file based on the command line parameters
# usage: ./genParams2 [OUTW] [DEPTH] [IN_TVALID_PROB] [OUT_TREADY_PROB]
#    where you will replace [OUTW] [DEPTH] [IN_TVALID_PROB] nad [OUT_TREADY_PROB]
#    with the desired value of those parameters.
#    Remember, if IN_TVALID_PROB or OUT_TREADY_PROB are 0, the simulator will randomize them.
# example: for OUTW=32, DEPTH=33, with random IN_TVALID_PROB and OUT_TREADY_PROB
#         run: ./genParams2 32 33 0 0 

if [ $# -ne 4 ]; then
    echo "ERROR: incorrect number of parameters given."
    echo "Usage: ./genParams2 [OUTW] [DEPTH] [IN_TVALID_PROB] [OUT_TREADY_PROB]"
    echo "See comments in genParams2 file for more information"
else
    echo "\`define OUTWVAL $1" > params.sv
    echo "\`define DEPTHVAL $2" >> params.sv
    echo "\`define TVPR $( sed 's/^[.]/0./' <<< "$3" )" >> params.sv
    echo "\`define TRPR $( sed 's/^[.]/0./' <<< "$4" )" >> params.sv
fi