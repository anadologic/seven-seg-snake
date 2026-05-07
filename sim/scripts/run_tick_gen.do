###############################################################################
# QuestaSim run script for tb_tick_gen
# Run from sim/ directory:
#   vsim -c -do scripts/run_tick_gen.do
###############################################################################

onerror {quit -code 1}

if {[file exists work]} { file delete -force work }
vlib work
vmap work work

vcom -2008 ../rtl/tick_gen.vhd
vcom -2008 tb/tb_tick_gen.vhd

vsim -c work.tb_tick_gen
run -all
quit -code 0
