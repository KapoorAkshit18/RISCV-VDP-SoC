# =============================================================================
# UVM + RTL filelist for RISCV-VDP-SoC (Phase 4)
# Canonical RTL reference: Design_Dir/RTL
# =============================================================================

# -----------------------------------------------------------------------------
# Include paths
# -----------------------------------------------------------------------------
+incdir+../../../../Design_Dir/RTL
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
# RTL sources (Canonical Design_Dir/RTL)
# -----------------------------------------------------------------------------
../../../../Design_Dir/RTL/cdc_reset_sync.v
../../../../Design_Dir/RTL/cpu_bus_adapter.v
../../../../Design_Dir/RTL/cpu_ram_subsystem.v
../../../../Design_Dir/RTL/cpu_soc_ram_top.v
../../../../Design_Dir/RTL/gpio_native_slave.v
../../../../Design_Dir/RTL/rf_telemetry_native.v
../../../../Design_Dir/RTL/riscv.v
../../../../Design_Dir/RTL/sensor_status_native.v
../../../../Design_Dir/RTL/soc_mem_interconnect.v
../../../../Design_Dir/RTL/soc_ram.v
../../../../Design_Dir/RTL/soc_uvm_dut.sv
../../../../Design_Dir/RTL/vdp_native_slave.v
../../../../Design_Dir/RTL/vga_timing_gen.v


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