#!/usr/bin/bash

# script to generate the params.sv file based on the command line parameters
# usage: ./genParams4 [INW] [R] [C] [MAXK] [TVALID_PROB] [TREADY_PROB]
#    where you will replace [*] with the desired value of those parameters.
#    Remember that if TVALID_PROB/TREADY_PROB = 0, the testbench will randomize it.

# example: for INW=12, R=8, C=7, MAXK=5 with random TREADY/TVALID 
# probabilities, run: 
#       ./genParams4 12 8 7 5 0 0 

if [ $# -ne 6 ]; then
    echo "ERROR: incorrect number of parameters given."
    echo "Usage: ./genParams4 [INW] [R] [C] [MAXK] [TVALID_PROB] [TREADY_PROB]"
    echo "See comments in genParams4 file for more information"
else
    echo "\`define INWVAL $1" > params.sv
    echo "\`define RVAL $2" >> params.sv
    echo "\`define CVAL $3" >> params.sv
    echo "\`define MAXKVAL $4" >> params.sv
    echo "\`define TVPR $( sed 's/^[.]/0./' <<< "$5" )" >> params.sv
    echo "\`define TRPR $( sed 's/^[.]/0./' <<< "$6" )" >> params.sv
fi