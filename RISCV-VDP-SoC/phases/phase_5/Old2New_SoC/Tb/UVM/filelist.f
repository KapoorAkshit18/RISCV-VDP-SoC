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

../../RTL/soc_uvm_dut.sv


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

tb/soc_native_if/soc_native_if.sv
tb/soc_pkg/soc_uvm_pkg.sv
tb_soc_uvm.sv