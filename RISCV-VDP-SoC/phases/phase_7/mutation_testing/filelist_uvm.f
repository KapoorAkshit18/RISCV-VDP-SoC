// ============================================================
// Phase 7 — UVM Mutation Testing Filelist
//
// This filelist references:
//   1. fault_models/ for RTL (soc_mem_interconnect.v is swapped with mutants)
//   2. Phase 5 UVM tb/ for all UVM testbench components
//   3. Phase 5 RNM/ for real-number models
//
// Working directory: phases/phase_7/mutation_testing/
//   ../fault_models/     = phases/phase_7/fault_models/
//   ../../phase_5/       = phases/phase_5/
//
// ============================================================

// ============================================================
// RTL / DUT sources (from phase_7/fault_models)
// ============================================================
+incdir+../fault_models
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_pkg
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_env
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_native_if

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

# RNM (from Phase 5)
../../phase_5/Old2New_SoC/Tb/RNM/temp_sensor_rnm.sv
../../phase_5/Old2New_SoC/Tb/RNM/adc_rnm.sv
../../phase_5/Old2New_SoC/Tb/RNM/sensor_adc_rnm.sv

// ============================================================
// UVM testbench sources (from Phase 5 UVM tb/)
// ============================================================
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_agent
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_agent/soc_sequence_item
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_sequencer
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_driver
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_monitor
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_env
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_base_test
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_native_if
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_ral
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_coverage
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_scoreboard
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_reference_model
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/tpu_monitor
+incdir+../../phase_5/Old2New_SoC/Tb/UVM/tb/sensor_monitor

#  soc_pkg
../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_pkg/soc_uvm_pkg.sv

// -----------------------------------------------------------------------------
// TPU (from fault_models)
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// Top-level UVM testbench (from Phase 5)
// -----------------------------------------------------------------------------
../../phase_5/Old2New_SoC/Tb/UVM/tb_cpu_soc_ram_top_end_to_end.sv
