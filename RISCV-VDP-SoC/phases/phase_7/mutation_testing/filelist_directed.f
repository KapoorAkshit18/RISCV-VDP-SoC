// ============================================================
// Phase 7 — Directed (Firmware-Driven) Mutation Testing Filelist
//
// This filelist compiles the FULL-SOC firmware-driven testbench
// (tb_soc_ram_top_with_firmw.sv) against fault_models/ RTL.
//
// The directed testbench instantiates cpu_soc_ram_top (identical
// DUT to the UVM flow), loads firmware via $readmemh, and monitors
// firmware completion markers for pass/fail.
//
// Working directory: phases/phase_7/mutation_testing/
//
// ============================================================

// ============================================================
// RTL / DUT sources (from phase_7/fault_models)
// ============================================================
+incdir+../fault_models

../fault_models/soc_mem_interconnect.v
../fault_models/soc_ram.v
../fault_models/gpio_native_slave.v
../fault_models/rf_telemetry_native.v
../fault_models/sensor_status_native.v
../fault_models/cdc_reset_sync.v
../fault_models/vga_timing_gen.v
../fault_models/vdp_native_slave.v
../fault_models/riscv.v
../fault_models/riscv_wrapper.v
../fault_models/cpu_soc_ram_top.v
../fault_models/cpu_bus_adapter.v

// TPU RTL
../fault_models/pe.v
../fault_models/register.v
../fault_models/sigmoid.v
../fault_models/systolic.v
../fault_models/pe_top.v
../fault_models/nn.v
../fault_models/axis_nn.v
../fault_models/nn_axi_wrapper.v
../fault_models/nn_axis_master.v
../fault_models/tpu_axis_top.v

// RNM (from Phase 5)
../../phase_5/Old2New_SoC/Tb/RNM/temp_sensor_rnm.sv
../../phase_5/Old2New_SoC/Tb/RNM/adc_rnm.sv
../../phase_5/Old2New_SoC/Tb/RNM/sensor_adc_rnm.sv

// Firmware-driven directed testbench (full SoC)
../../phase_5/Old2New_SoC/tb_soc_ram_top_with_firmw.sv
