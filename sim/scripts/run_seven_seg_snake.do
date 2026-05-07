###############################################################################
# QuestaSim run script for tb_seven_seg_snake (top-level integration test)
# Run from sim/ directory:
#   vsim -c -do scripts/run_seven_seg_snake.do
###############################################################################

onerror {quit -code 1}

if {[file exists work]} { file delete -force work }
vlib work
vmap work work

# Compile order matters: package first, then leaf modules, then TB.
vcom -2008 ../rtl/seg_mux.vhd
vcom -2008 ../rtl/sync_reset.vhd
vcom -2008 ../rtl/debouncer.vhd
vcom -2008 ../rtl/tick_gen.vhd
vcom -2008 ../rtl/snake_fsm.vhd
vcom -2008 ../rtl/seg_decoder.vhd
vcom -2008 tb/tb_seven_seg_snake.vhd

vsim -c work.tb_seven_seg_snake
run -all
quit -code 0
