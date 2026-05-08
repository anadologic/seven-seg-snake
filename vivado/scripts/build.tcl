###############################################################################
# build.tcl - Vivado project + bitstream build for seven-seg-snake
#
# Target board : Digilent Nexys A7-100T
# Target part  : xc7a100tcsg324-1
# Top entity   : seven_seg_snake
#
# Usage (from repo root):
#   F:\Xilinx\Vivado\2023.1\bin\vivado.bat -mode batch -source vivado/scripts/build.tcl
#
# Or call build.bat which wraps this. The script:
#   1. Creates an in-memory project under vivado/build/
#   2. Adds all rtl/*.vhd as VHDL-2008 design sources
#   3. Adds the constraints file
#   4. Runs synthesis -> implementation -> bitstream
#   5. Reports utilization + timing
#   6. Copies the .bit (and .bin) to vivado/build/
#
# The build directory is wiped at the start of every run so the script
# is idempotent.
###############################################################################

# ----------------------------------------------------------------------------
# Paths (resolved relative to this script's location)
# ----------------------------------------------------------------------------
set script_dir [file normalize [file dirname [info script]]]
set repo_root  [file normalize [file join $script_dir .. ..]]

set rtl_dir       [file join $repo_root rtl]
set xdc_file      [file join $repo_root constraint Nexys-4-DDR-Master.xdc]
set build_dir     [file join $repo_root vivado build]
set proj_name     "seven_seg_snake"
set top_entity    "seven_seg_snake"
set part          "xc7a100tcsg324-1"
set board_part    "digilentinc.com:nexys-a7-100t:part0:1.2"

# ----------------------------------------------------------------------------
# Clean and (re)create the build directory
# ----------------------------------------------------------------------------
if {[file exists $build_dir]} {
    file delete -force $build_dir
}
file mkdir $build_dir

# ----------------------------------------------------------------------------
# Create the project (in-memory; not saved unless -save passed via env)
# ----------------------------------------------------------------------------
puts "INFO: Creating project '$proj_name' in $build_dir"
create_project $proj_name $build_dir -part $part -force

# Try to set the board part for IP support; harmless if not installed.
if {[catch {set_property board_part $board_part [current_project]} err]} {
    puts "WARN: board_part '$board_part' not available in this Vivado install."
    puts "WARN: continuing without it ($err)"
}

# ----------------------------------------------------------------------------
# Add design sources (VHDL-2008)
# ----------------------------------------------------------------------------
set rtl_files [list \
    [file join $rtl_dir seg_mux.vhd]      \
    [file join $rtl_dir sync_reset.vhd]   \
    [file join $rtl_dir debouncer.vhd]    \
    [file join $rtl_dir tick_gen.vhd]     \
    [file join $rtl_dir snake_fsm.vhd]    \
    [file join $rtl_dir seg_decoder.vhd]  \
    [file join $rtl_dir seven_seg_snake.vhd] \
]

foreach f $rtl_files {
    if {![file exists $f]} {
        puts "ERROR: missing RTL file $f"
        exit 1
    }
    add_files -norecurse -fileset sources_1 $f
}

# Mark all VHDL files as VHDL-2008 (matches the QuestaSim flow).
foreach f [get_files -of_objects [get_filesets sources_1] *.vhd] {
    set_property file_type {VHDL 2008} $f
}

set_property top $top_entity [current_fileset]
set_property top_lib xil_defaultlib [current_fileset]

# ----------------------------------------------------------------------------
# Add constraints
# ----------------------------------------------------------------------------
if {![file exists $xdc_file]} {
    puts "ERROR: constraint file not found: $xdc_file"
    exit 1
}
add_files -norecurse -fileset constrs_1 $xdc_file

# ----------------------------------------------------------------------------
# Synthesis
# ----------------------------------------------------------------------------
puts "INFO: launching synthesis..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: synthesis failed."
    exit 1
}
puts "INFO: synthesis OK"

# ----------------------------------------------------------------------------
# Implementation + bitstream
# ----------------------------------------------------------------------------
puts "INFO: launching implementation + bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: implementation/bitstream failed."
    exit 1
}
puts "INFO: implementation + bitstream OK"

# ----------------------------------------------------------------------------
# Reports
# ----------------------------------------------------------------------------
open_run impl_1
puts "----- TIMING SUMMARY -----"
report_timing_summary -no_header -no_detailed_paths
puts "----- UTILIZATION -----"
report_utilization -hierarchical -hierarchical_depth 1

# ----------------------------------------------------------------------------
# Copy bitstream to a stable location
# ----------------------------------------------------------------------------
set bit_src [file join $build_dir ${proj_name}.runs impl_1 ${top_entity}.bit]
set bit_dst [file join $build_dir ${top_entity}.bit]
if {[file exists $bit_src]} {
    file copy -force $bit_src $bit_dst
    puts "INFO: bitstream copied to $bit_dst"
} else {
    puts "WARN: bitstream not found at $bit_src"
}

puts "INFO: build complete."
