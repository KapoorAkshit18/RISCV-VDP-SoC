# =============================================================================
# filelist.f (Phase 5 Old2New_SoC)
# Canonical RTL reference: Design_Dir/RTL
# =============================================================================

# -----------------------------------------------------------------------------
# Include directories
# -----------------------------------------------------------------------------
+incdir+../../../../Design_Dir/RTL
+incdir+Tb
+incdir+Tb/directed_tb


# -----------------------------------------------------------------------------
# CPU / RISC-V (Canonical Design_Dir/RTL)
# -----------------------------------------------------------------------------
../../../../Design_Dir/RTL/riscv.v
../../../../Design_Dir/RTL/riscv_wrapper.v
../../../../Design_Dir/RTL/cpu_bus_adapter.v


# -----------------------------------------------------------------------------
# SoC memory subsystem (Canonical Design_Dir/RTL)
# -----------------------------------------------------------------------------
../../../../Design_Dir/RTL/soc_mem_interconnect.v
../../../../Design_Dir/RTL/soc_ram.v
../../../../Design_Dir/RTL/cpu_ram_subsystem.v


# -----------------------------------------------------------------------------
# SoC peripherals (Canonical Design_Dir/RTL)
# -----------------------------------------------------------------------------
../../../../Design_Dir/RTL/gpio_native_slave.v
../../../../Design_Dir/RTL/rf_telemetry_native.v
../../../../Design_Dir/RTL/sensor_status_native.v
../../../../Design_Dir/RTL/vdp_native_slave.v
../../../../Design_Dir/RTL/vga_timing_gen.v

# RNM
tb/RNM/temp_sensor_rnm.sv
tb/RNM/adc_rnm.sv
tb/RNM/sensor_adc_rnm.sv


# -----------------------------------------------------------------------------
# TPU subsystem (Canonical Design_Dir/RTL)
# -----------------------------------------------------------------------------
../../../../Design_Dir/RTL/pe.v
../../../../Design_Dir/RTL/register.v
../../../../Design_Dir/RTL/sigmoid.v
../../../../Design_Dir/RTL/systolic.v
../../../../Design_Dir/RTL/pe_top.v
../../../../Design_Dir/RTL/nn.v
../../../../Design_Dir/RTL/axis_nn.v
../../../../Design_Dir/RTL/nn_axi_wrapper.v
../../../../Design_Dir/RTL/nn_axis_master.v
../../../../Design_Dir/RTL/tpu_axis_top.v


# -----------------------------------------------------------------------------
# Clock / reset (Canonical Design_Dir/RTL)
# -----------------------------------------------------------------------------
../../../../Design_Dir/RTL/cdc_reset_sync.v


# -----------------------------------------------------------------------------
# SoC top (Canonical Design_Dir/RTL)
# -----------------------------------------------------------------------------
../../../../Design_Dir/RTL/cpu_soc_ram_top.v


# -----------------------------------------------------------------------------
# Testbench
# -----------------------------------------------------------------------------
tb_soc_ram_top_no_firmw.sv
tb_soc_ram_top_with_firmw.sv
