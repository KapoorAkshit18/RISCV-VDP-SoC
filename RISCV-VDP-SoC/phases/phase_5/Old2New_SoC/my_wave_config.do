onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {CLOCK / RESET}
add wave -noupdate /tb_cpu_soc_ram_top/clk
add wave -noupdate /tb_cpu_soc_ram_top/resetn
add wave -noupdate /tb_cpu_soc_ram_top/pixel_clk
add wave -noupdate -divider {CPU NATIVE MEMORY BUS}
add wave -noupdate /tb_cpu_soc_ram_top/dut/m_valid
add wave -noupdate /tb_cpu_soc_ram_top/dut/m_write
add wave -noupdate /tb_cpu_soc_ram_top/dut/m_addr
add wave -noupdate /tb_cpu_soc_ram_top/dut/m_wdata
add wave -noupdate /tb_cpu_soc_ram_top/dut/m_strb
add wave -noupdate /tb_cpu_soc_ram_top/dut/m_ready
add wave -noupdate /tb_cpu_soc_ram_top/dut/m_rdata
add wave -noupdate -divider {SOC MEMORY INTERCONNECT}
add wave -noupdate /tb_cpu_soc_ram_top/dut/u_interconnect/m_valid
add wave -noupdate /tb_cpu_soc_ram_top/dut/u_interconnect/m_write
add wave -noupdate /tb_cpu_soc_ram_top/dut/u_interconnect/m_addr
add wave -noupdate /tb_cpu_soc_ram_top/dut/u_interconnect/m_wdata
add wave -noupdate /tb_cpu_soc_ram_top/dut/u_interconnect/m_strb
add wave -noupdate /tb_cpu_soc_ram_top/dut/u_interconnect/m_ready
add wave -noupdate /tb_cpu_soc_ram_top/dut/u_interconnect/m_rdata
add wave -noupdate /tb_cpu_soc_ram_top/dut/u_interconnect/nn_sel
add wave -noupdate /tb_cpu_soc_ram_top/dut/u_interconnect/nn_valid
add wave -noupdate /tb_cpu_soc_ram_top/dut/u_interconnect/nn_write
add wave -noupdate /tb_cpu_soc_ram_top/dut/u_interconnect/nn_addr
add wave -noupdate /tb_cpu_soc_ram_top/dut/u_interconnect/nn_wdata
add wave -noupdate /tb_cpu_soc_ram_top/dut/u_interconnect/nn_strb
add wave -noupdate /tb_cpu_soc_ram_top/dut/u_interconnect/nn_ready
add wave -noupdate /tb_cpu_soc_ram_top/dut/u_interconnect/nn_rdata
add wave -noupdate -divider {TPU MMIO / CONTROL}
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/axis_start
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/axis_busy
add wave -noupdate -color {Medium Blue} /tb_cpu_soc_ram_top/dut/tpu/axis_done
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/bus_req
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/bus_write
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/bus_addr
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/bus_wdata
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/bus_strb
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/bus_ready
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/bus_rdata
add wave -noupdate -divider {TPU WEIGHTS / INPUTS}
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/weight0
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/weight1
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/weight2
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/weight3
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/weight4
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/input0
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/input1
add wave -noupdate -divider {AXI4-STREAM TX}
add wave -noupdate -color {Medium Blue} /tb_cpu_soc_ram_top/dut/tpu/in_tvalid
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/in_tready
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/in_tdata
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/in_tlast
add wave -noupdate -divider {AXI4-STREAM RX}
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/out_tvalid
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/out_tready
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/out_tdata
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/out_tlast
add wave -noupdate -divider {AXIS MASTER FSM}
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/axis_start
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/axis_busy
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/axis_done
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/state_reg
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/beat_reg
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/m_axis_tvalid
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/m_axis_tready
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/m_axis_tdata
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/m_axis_tlast
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/s_axis_tvalid
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/s_axis_tready
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/s_axis_tdata
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/s_axis_tlast
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/result0
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/result1
add wave -noupdate -divider {AXIS NN ACCELERATOR}
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/state_reg
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/mm2s_data_count
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/mm2s_ready_reg
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/s_axis_tvalid
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/s_axis_tready
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/s_axis_tdata
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/s_axis_tlast
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/m_axis_tvalid
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/m_axis_tready
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/m_axis_tdata
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/m_axis_tlast
add wave -noupdate -divider {TPU RESULTS}
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/result0
add wave -noupdate /tb_cpu_soc_ram_top/dut/tpu/result1
add wave -noupdate /tb_cpu_soc_ram_top/dut/result0
add wave -noupdate /tb_cpu_soc_ram_top/dut/result1
add wave -noupdate -divider GPIO
add wave -noupdate /tb_cpu_soc_ram_top/dut/gpio_valid
add wave -noupdate /tb_cpu_soc_ram_top/dut/gpio_write
add wave -noupdate /tb_cpu_soc_ram_top/dut/gpio_addr
add wave -noupdate /tb_cpu_soc_ram_top/dut/gpio_wdata
add wave -noupdate /tb_cpu_soc_ram_top/dut/gpio_strb
add wave -noupdate /tb_cpu_soc_ram_top/dut/gpio_ready
add wave -noupdate /tb_cpu_soc_ram_top/dut/gpio_rdata
add wave -noupdate -divider RAM
add wave -noupdate /tb_cpu_soc_ram_top/dut/ram_valid
add wave -noupdate /tb_cpu_soc_ram_top/dut/ram_write
add wave -noupdate /tb_cpu_soc_ram_top/dut/ram_addr
add wave -noupdate /tb_cpu_soc_ram_top/dut/ram_wdata
add wave -noupdate /tb_cpu_soc_ram_top/dut/ram_strb
add wave -noupdate /tb_cpu_soc_ram_top/dut/ram_ready
add wave -noupdate /tb_cpu_soc_ram_top/dut/ram_rdata
add wave -noupdate -divider RF
add wave -noupdate /tb_cpu_soc_ram_top/dut/rf_valid
add wave -noupdate /tb_cpu_soc_ram_top/dut/rf_write
add wave -noupdate /tb_cpu_soc_ram_top/dut/rf_addr
add wave -noupdate /tb_cpu_soc_ram_top/dut/rf_wdata
add wave -noupdate /tb_cpu_soc_ram_top/dut/rf_strb
add wave -noupdate /tb_cpu_soc_ram_top/dut/rf_ready
add wave -noupdate /tb_cpu_soc_ram_top/dut/rf_rdata
add wave -noupdate -divider SENSOR
add wave -noupdate /tb_cpu_soc_ram_top/dut/sensor_valid
add wave -noupdate /tb_cpu_soc_ram_top/dut/sensor_write
add wave -noupdate /tb_cpu_soc_ram_top/dut/sensor_addr
add wave -noupdate /tb_cpu_soc_ram_top/dut/sensor_wdata
add wave -noupdate /tb_cpu_soc_ram_top/dut/sensor_strb
add wave -noupdate /tb_cpu_soc_ram_top/dut/sensor_ready
add wave -noupdate /tb_cpu_soc_ram_top/dut/sensor_rdata
add wave -noupdate -divider {TESTBENCH OBSERVATION}
add wave -noupdate /tb_cpu_soc_ram_top/trap
add wave -noupdate /tb_cpu_soc_ram_top/gpio_in
add wave -noupdate /tb_cpu_soc_ram_top/gpio_out
add wave -noupdate /tb_cpu_soc_ram_top/gpio_oe
add wave -noupdate /tb_cpu_soc_ram_top/rf_enable_o
add wave -noupdate /tb_cpu_soc_ram_top/hsync_o
add wave -noupdate /tb_cpu_soc_ram_top/vsync_o
add wave -noupdate /tb_cpu_soc_ram_top/pixel_x_o
add wave -noupdate /tb_cpu_soc_ram_top/pixel_y_o
add wave -noupdate /tb_cpu_soc_ram_top/rgb_r_o
add wave -noupdate /tb_cpu_soc_ram_top/rgb_g_o
add wave -noupdate /tb_cpu_soc_ram_top/rgb_b_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {axi_done {3535000 ps} 1} {axi_start {2945000 ps} 1 default {Pale Green}} {tx2 {2955000 ps} 1 default Gray30} {tx1 {3025000 ps} 1} {rx1 {3505000 ps} 1 default {Dark Green}} {rx2 {3525000 ps} 0}
quietly wave cursor active 6
configure wave -namecolwidth 200
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {3524975 ps} {3525057 ps}
