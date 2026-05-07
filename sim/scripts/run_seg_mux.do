###############################################################################
# QuestaSim run script for tb_seg_mux
# Run from sim/ directory:
#   vsim -c -do scripts/run_seg_mux.do
###############################################################################

onerror {quit -code 1}

if {[file exists work]} { file delete -force work }
vlib work
vmap work work

vcom -2008 ../rtl/seg_mux.vhd
vcom -2008 tb/tb_seg_mux.vhd

vsim -c work.tb_seg_mux
run -all
quit -code 0
