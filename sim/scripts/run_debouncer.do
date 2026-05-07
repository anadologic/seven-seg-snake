###############################################################################
# QuestaSim run script for tb_debouncer
# Run from sim/ directory:
#   vsim -c -do scripts/run_debouncer.do
###############################################################################

onerror {quit -code 1}

if {[file exists work]} { file delete -force work }
vlib work
vmap work work

vcom -2008 ../rtl/debouncer.vhd
vcom -2008 tb/tb_debouncer.vhd

vsim -c work.tb_debouncer
run -all
quit -code 0
