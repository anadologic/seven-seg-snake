###############################################################################
# QuestaSim run script for tb_snake_fsm
# Run from sim/ directory:
#   vsim -c -do scripts/run_snake_fsm.do
###############################################################################

onerror {quit -code 1}

if {[file exists work]} { file delete -force work }
vlib work
vmap work work

vcom -2008 ../rtl/snake_fsm.vhd
vcom -2008 tb/tb_snake_fsm.vhd

vsim -c work.tb_snake_fsm
run -all
quit -code 0
