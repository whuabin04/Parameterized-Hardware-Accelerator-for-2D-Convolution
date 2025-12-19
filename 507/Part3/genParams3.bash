#!/usr/bin/bash

# script to generate the params.sv file based on the command line parameters
# usage: ./genParams3 [INW] [R] [C] [MAXK] [TVALID_PROB]
#    where you will replace [INW] [R] [C] [MAXK] and [TVALID_PROB] with the 
#    desired value of those parameters.
#    Remember that if TVALID_PROB = 0, the testbench will randomize it.
# example: for INW=16, R=7, C=6, MAXK=5 with random TVALID_PROB, run:
#      ./genParams3 16 7 6 5 0

if [ $# -ne 5 ]; then
    echo "ERROR: incorrect number of parameters given."
    echo "Usage: ./genParams3 [INW] [R] [C] [MAXK] [TVALID_PROB]"
    echo "See comments in genParams3 file for more information"
else
    echo "\`define INWVAL $1" > params.sv
    echo "\`define RVAL $2" >> params.sv
    echo "\`define CVAL $3" >> params.sv
    echo "\`define MAXKVAL $4" >> params.sv
    echo "\`define TVPR $( sed 's/^[.]/0./' <<< "$5" )" >> params.sv
fi
