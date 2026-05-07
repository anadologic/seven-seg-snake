###############################################################################
# QuestaSim run script for tb_sync_reset
# Run from sim/ directory:
#   vsim -c -do scripts/run_sync_reset.do
###############################################################################

onerror {quit -code 1}

# Recreate work library cleanly
if {[file exists work]} { file delete -force work }
vlib work
vmap work work

# Compile DUT + TB
vcom -2008 ../rtl/sync_reset.vhd
vcom -2008 tb/tb_sync_reset.vhd

# Elaborate, run, exit
vsim -c work.tb_sync_reset
run -all
quit -code 0
