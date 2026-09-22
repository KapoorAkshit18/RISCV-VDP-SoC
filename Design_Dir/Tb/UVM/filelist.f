// ============================================================
// RTL / DUT sources
// ============================================================
+incdir+tb
+incdir+tb/soc_pkg
+incdir+tb/soc_env
+incdir+tb/soc_native_if

../../RTL/soc_mem_interconnect.v
../../RTL/soc_ram.v
../../RTL/gpio_native_slave.v
../../RTL/rf_telemetry_native.v
../../RTL/sensor_status_native.v
../../RTL/cdc_reset_sync.v
../../RTL/vga_timing_gen.v
../../RTL/vdp_native_slave.v
../../RTL/riscv.v
../../RTL/riscv_wrapper.v
../../RTL/cpu_soc_ram_top.v
../../RTL/soc_uvm_dut.sv
../../RTL/cpu_bus_adapter.v

# RNM
../RNM/temp_sensor_rnm.sv
../RNM/adc_rnm.sv
../RNM/sensor_adc_rnm.sv

// ============================================================
// UVM testbench sources
// ============================================================
+incdir+tb
+incdir+tb/soc_agent
+incdir+tb/soc_agent/soc_sequence_item
+incdir+tb/soc_sequencer
+incdir+tb/soc_driver
+incdir+tb/soc_monitor
+incdir+tb/soc_env
+incdir+tb/soc_base_test
+incdir+tb/soc_native_if
+incdir+tb/soc_ral
+incdir+tb/soc_coverage
+incdir+tb/soc_scoreboard
+incdir+tb/soc_reference_model
+incdir+tb/tpu_monitor


#  soc_pkg
tb/soc_pkg/soc_uvm_pkg.sv

# -----------------------------------------------------------------------------
# TPU
# -----------------------------------------------------------------------------

../../../TPU/pe.v
../../../TPU/register.v
../../../TPU/sigmoid.v
../../../TPU/systolic.v
../../../TPU/pe_top.v
../../../TPU/nn.v

../../../TPU/axis_nn.v
../../../TPU/nn_axi_wrapper.v
../../../TPU/nn_axis_master.v
../../../TPU/tpu_axis_top.v

tb_cpu_soc_ram_top_end_to_end.sv