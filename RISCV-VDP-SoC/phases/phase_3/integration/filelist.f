// ============================================================
// RISCV-VDP-SoC RTL FILELIST (Phase 3 Integration)
// Canonical RTL reference: Design_Dir/RTL
// ============================================================

+incdir+../../../../Design_Dir/RTL

// ------------------------------------------------------------
// Basic / support RTL (Canonical Design_Dir/RTL)
// ------------------------------------------------------------
../../../../Design_Dir/RTL/cdc_reset_sync.v
../../../../Design_Dir/RTL/riscv.v
../../../../Design_Dir/RTL/riscv_wrapper.v

// ------------------------------------------------------------
// CPU bus / memory subsystem (Canonical Design_Dir/RTL)
// ------------------------------------------------------------
../../../../Design_Dir/RTL/cpu_bus_adapter.v
../../../../Design_Dir/RTL/soc_ram.v
../../../../Design_Dir/RTL/soc_mem_interconnect.v
../../../../Design_Dir/RTL/cpu_ram_subsystem.v

// ------------------------------------------------------------
// Native peripherals (Canonical Design_Dir/RTL)
// ------------------------------------------------------------
../../../../Design_Dir/RTL/gpio_native_slave.v
../../../../Design_Dir/RTL/sensor_status_native.v
../../../../Design_Dir/RTL/rf_telemetry_native.v

// ------------------------------------------------------------
// VDP / VGA (Canonical Design_Dir/RTL)
// ------------------------------------------------------------
../../../../Design_Dir/RTL/vga_timing_gen.v
../../../../Design_Dir/RTL/vdp_native_slave.v

// ------------------------------------------------------------
// SoC top-level (Canonical Design_Dir/RTL)
// ------------------------------------------------------------
../../../../Design_Dir/RTL/cpu_soc_ram_top.v

// ------------------------------------------------------------
// Testbench
// ------------------------------------------------------------
./tb/directed/tb_soc_ram_top_sigmoid.sv
./tb/directed/tb_soc_ram_top_relu.sv
