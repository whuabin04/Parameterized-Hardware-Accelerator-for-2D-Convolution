##############################################
# Setup: fill out the following parameters: name of clock signal, clock period (ns),
# reset signal name (if used), name of top-level module, name of source file
set CLK_NAME "clk";
set CLK_PERIOD 0.93;
# minimum clk period for 12 9 8 5 is 0.930ns - 2 stages 
# minimum clk period for 12 9 8 5 is 0.900ns - 3 stages 

# minimum clk period for 18 9 8 5 is 1.380ns - unpiped
# minimum clk period for 18 9 8 5 is 1.060ns - 2 stages
# minimum clk period for 18 9 8 5 is 0.910ns - 3 stages
# minimum clk period for 18 9 8 5 is 1.050ns - 6 stages

# minimum clk period for 24 16 17 9 is 1.580ns - unpiped
# minimum clk period for 24 16 17 9 is 1.140ns - 2 stages
# minimum clk period for 24 16 17 9 is 1.100ns - 3 stages
# minimum clk period for 24 16 17 9 is 1.550ns - 6 stages 
set RST_NAME "reset";
set TOP_MOD_NAME "Conv";
set SRC_FILE [list "Conv.sv" "input_mems.sv" "fifo_out.sv" "mac_pipe.sv"];
# If you have multiple source files, change the line above to list them all like this:
# set SRC_FILE [list "file1.sv" "file2.sv"];
###############################################

# setup
source setupdc.tcl
file mkdir work_synth
date
pid
pwd
getenv USER
getenv HOSTNAME


# optimize FSMs
set fsm_auto_inferring "true"; 
set fsm_enable_state_minimization "true";

define_design_lib WORK -path work_synth
analyze $SRC_FILE -format sverilog
elaborate -work WORK $TOP_MOD_NAME

###### CLOCKS AND PORTS #######
set CLK_PORT [get_ports $CLK_NAME]
set TMP1 [remove_from_collection [all_inputs] $CLK_PORT]
set INPUTS [remove_from_collection $TMP1 $RST_NAME]
create_clock -period $CLK_PERIOD $CLK_PORT
set_input_delay 0.08 -max -clock $CLK_NAME $INPUTS
set_output_delay 0.08 -max -clock $CLK_NAME [all_outputs]


###### OPTIMIZATION #######
set_max_area 0 

###### RUN #####
compile_ultra
report_area
report_power
report_timing
report_timing -loops
date
# write -f verilog $TOP_MOD_NAME -output gates.v -hierarchy

quit

