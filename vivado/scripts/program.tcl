###############################################################################
# program.tcl - Program the Nexys A7 over JTAG with the latest bitstream
#
# Usage (from repo root):
#   F:\Xilinx\Vivado\2023.1\bin\vivado.bat -mode batch -source vivado/scripts/program.tcl
#
# Assumes build.tcl has already produced vivado/build/seven_seg_snake.bit.
# This loads the bitstream into volatile FPGA RAM (lost on power cycle).
###############################################################################

set script_dir [file normalize [file dirname [info script]]]
set repo_root  [file normalize [file join $script_dir .. ..]]
set bit_file   [file join $repo_root vivado build seven_seg_snake.bit]

if {![file exists $bit_file]} {
    puts "ERROR: bitstream not found: $bit_file"
    puts "ERROR: run build.tcl first."
    exit 1
}

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

# Find the Artix-7 device on the Nexys A7
set dev [lindex [get_hw_devices -filter {NAME =~ "*xc7a100t*"}] 0]
if {$dev eq ""} {
    puts "ERROR: no xc7a100t device found on JTAG chain."
    close_hw_manager
    exit 1
}
current_hw_device $dev

set_property PROGRAM.FILE $bit_file $dev
program_hw_devices $dev

puts "INFO: device programmed with $bit_file"

close_hw_target
disconnect_hw_server
close_hw_manager
