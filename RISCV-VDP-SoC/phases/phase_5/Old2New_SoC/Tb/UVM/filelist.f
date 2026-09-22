// ============================================================
// RTL / DUT sources (Canonical Design_Dir/RTL)
// ============================================================
+incdir+../../../../../../Design_Dir/RTL
+incdir+tb
+incdir+tb/soc_pkg
+incdir+tb/soc_env
+incdir+tb/soc_native_if

../../../../../../Design_Dir/RTL/soc_mem_interconnect.v
../../../../../../Design_Dir/RTL/soc_ram.v
../../../../../../Design_Dir/RTL/gpio_native_slave.v
../../../../../../Design_Dir/RTL/rf_telemetry_native.v
../../../../../../Design_Dir/RTL/sensor_status_native.v
../../../../../../Design_Dir/RTL/cdc_reset_sync.v
../../../../../../Design_Dir/RTL/vga_timing_gen.v
../../../../../../Design_Dir/RTL/vdp_native_slave.v
../../../../../../Design_Dir/RTL/riscv.v
../../../../../../Design_Dir/RTL/riscv_wrapper.v
../../../../../../Design_Dir/RTL/cpu_soc_ram_top.v
../../../../../../Design_Dir/RTL/soc_uvm_dut.sv
../../../../../../Design_Dir/RTL/cpu_bus_adapter.v

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
# TPU (Canonical Design_Dir/RTL)
# -----------------------------------------------------------------------------
../../../../../../Design_Dir/RTL/pe.v
../../../../../../Design_Dir/RTL/register.v
../../../../../../Design_Dir/RTL/sigmoid.v
../../../../../../Design_Dir/RTL/systolic.v
../../../../../../Design_Dir/RTL/pe_top.v
../../../../../../Design_Dir/RTL/nn.v
../../../../../../Design_Dir/RTL/axis_nn.v
../../../../../../Design_Dir/RTL/nn_axi_wrapper.v
../../../../../../Design_Dir/RTL/nn_axis_master.v
../../../../../../Design_Dir/RTL/tpu_axis_top.v

# -----------------------------------------------------------------------------
# Top-level UVM testbench
# -----------------------------------------------------------------------------
tb_cpu_soc_ram_top_end_to_end.sv