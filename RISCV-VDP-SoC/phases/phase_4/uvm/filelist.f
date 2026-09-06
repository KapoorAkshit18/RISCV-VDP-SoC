# =============================================================================
# UVM + RTL filelist for RISCV-VDP-SoC
# =============================================================================

# -----------------------------------------------------------------------------
# Include paths
# -----------------------------------------------------------------------------

+incdir+rtl
+incdir+tb
+incdir+tb/soc_pkg
+incdir+tb/soc_agent
+incdir+tb/soc_agent/soc_sequence_item
+incdir+tb/soc_agent/soc_sequencer
+incdir+tb/soc_driver
+incdir+tb/soc_monitor
+incdir+tb/soc_env
+incdir+tb/soc_native_if
+incdir+tb/soc_base_test
+incdir+tb/soc_ral
+incdir+tb/soc_coverage
# -----------------------------------------------------------------------------
# RTL sources
# -----------------------------------------------------------------------------

rtl/cdc_reset_sync.v
rtl/cpu_bus_adapter.v
rtl/cpu_ram_subsystem.v
rtl/cpu_soc_ram_top.v
rtl/cpu_soc_ram_top_smoke.v
rtl/gpio_native_slave.v
rtl/rf_telemetry_native.v
rtl/riscv.v
rtl/sensor_status_native.v
rtl/soc_mem_interconnect.v
rtl/soc_ram.v
rtl/soc_uvm_dut.sv
rtl/vdp_native_slave.v
rtl/vga_timing_gen.v


# -----------------------------------------------------------------------------
# UVM support and interface
# -----------------------------------------------------------------------------

soc_native_if.sv


# -----------------------------------------------------------------------------
# UVM package + classes
# -----------------------------------------------------------------------------

tb/soc_pkg/soc_uvm_pkg.sv


# -----------------------------------------------------------------------------
# Top-level UVM testbench
# -----------------------------------------------------------------------------

tb_soc_uvm.sv