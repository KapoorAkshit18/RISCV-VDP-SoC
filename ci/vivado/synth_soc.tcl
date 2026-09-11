# =============================================================================
# synth_soc.tcl
# Non-project batch-mode Vivado synthesis script for RISCV-VDP-SoC
# =============================================================================

set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize "$script_dir/../.."]

# Configurable parameters (can be overridden via environment variables)
if {[info exists env(VIVADO_TOP_MODULE)]} {
    set top_module $env(VIVADO_TOP_MODULE)
} else {
    set top_module "cpu_soc_ram_top"
}

if {[info exists env(VIVADO_PART)]} {
    set part $env(VIVADO_PART)
} else {
    set part "xc7z020clg484-1"
}

if {[info exists env(VIVADO_OUTPUT_DIR)]} {
    set out_dir $env(VIVADO_OUTPUT_DIR)
} else {
    set out_dir [file normalize "$root_dir/ci/vivado/reports"]
}

file mkdir $out_dir

puts "=================================================================="
puts "  Vivado Synthesis Configuration"
puts "  Top Module : $top_module"
puts "  Target Part: $part"
puts "  Output Dir : $out_dir"
puts "  Root Dir   : $root_dir"
puts "=================================================================="

# 1. Read RTL source files directly from Design_Dir/RTL
set rtl_dir "$root_dir/Design_Dir/RTL"
set rtl_files [list \
    "$rtl_dir/riscv.v" \
    "$rtl_dir/riscv_wrapper.v" \
    "$rtl_dir/cpu_bus_adapter.v" \
    "$rtl_dir/soc_mem_interconnect.v" \
    "$rtl_dir/soc_ram.v" \
    "$rtl_dir/gpio_native_slave.v" \
    "$rtl_dir/rf_telemetry_native.v" \
    "$rtl_dir/sensor_status_native.v" \
    "$rtl_dir/vdp_native_slave.v" \
    "$rtl_dir/vga_timing_gen.v" \
    "$rtl_dir/cdc_reset_sync.v" \
    "$rtl_dir/pe.v" \
    "$rtl_dir/register.v" \
    "$rtl_dir/sigmoid.v" \
    "$rtl_dir/systolic.v" \
    "$rtl_dir/pe_top.v" \
    "$rtl_dir/nn.v" \
    "$rtl_dir/axis_nn.v" \
    "$rtl_dir/nn_axi_wrapper.v" \
    "$rtl_dir/nn_axis_master.v" \
    "$rtl_dir/tpu_axis_top.v" \
    "$rtl_dir/cpu_soc_ram_top.v" \
]

foreach f $rtl_files {
    if {[file exists $f]} {
        if {[string match "*.sv" $f]} {
            puts "Reading SystemVerilog: $f"
            read_verilog -sv $f
        } else {
            puts "Reading Verilog: $f"
            read_verilog $f
        }
    } else {
        puts "ERROR: Source file not found: $f"
        exit 1
    }
}

# 2. Read Synthesis Constraints
set xdc_file "$script_dir/constraints/timing_synth.xdc"
if {[file exists $xdc_file]} {
    puts "Reading constraints: $xdc_file"
    read_xdc $xdc_file
} else {
    puts "WARNING: Constraints file not found: $xdc_file"
}

# 3. Synthesize Design
puts "Starting synth_design for $top_module ($part)..."
synth_design -top $top_module -part $part -mode out_of_context

# 4. Generate Reports
puts "Generating reports..."
report_utilization -file "$out_dir/utilization.rpt"
report_timing_summary -file "$out_dir/timing_summary.rpt" -max_paths 10
report_drc -file "$out_dir/drc.rpt"

# 5. Save Synthesized Checkpoint
puts "Saving checkpoint..."
write_checkpoint -force "$out_dir/${top_module}_synth.dcp"

puts "=================================================================="
puts "  Vivado Synthesis Completed Successfully!"
puts "  Reports saved to: $out_dir"
puts "=================================================================="
exit 0
