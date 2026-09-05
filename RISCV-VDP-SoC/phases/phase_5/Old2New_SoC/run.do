# =============================================================================
# run.do
#
# Questa/ModelSim waveform script
# DUT hierarchy:
#
#   tb_cpu_soc_ram_top
#       |
#       +-- dut : cpu_soc_ram_top
#             |
#             +-- cpu
#             +-- adapter
#             +-- interconnect
#             +-- ram
#             +-- gpio
#             +-- rf
#             +-- sensor
#             +-- vdp
#             +-- tpu
#                   |
#                   +-- u_nn_axi_wrapper
#                   +-- u_nn_axis_master
#                   +-- u_axis_nn
#
# Actual simulation top:
#       sim:/tb_cpu_soc_ram_top
#
# Actual DUT:
#       sim:/tb_cpu_soc_ram_top/dut
# =============================================================================


# -----------------------------------------------------------------------------
# 1. Start / reset waveform window
# -----------------------------------------------------------------------------

view wave
delete wave *


# -----------------------------------------------------------------------------
# 2. Waveform appearance
# -----------------------------------------------------------------------------

configure wave -wavebackground white
configure wave -waveeventbackground white
configure wave -wavestripbackground white
configure wave -gridcolor grey50
configure wave -textcolor black
configure wave -timecolor black
configure wave -background white
configure wave -foreground black
configure wave -signalnamewidth 1
configure wave -namecolwidth 200


# =============================================================================
# GROUP 1: CLOCK / RESET
# =============================================================================

add wave -divider "CLOCK / RESET"

add wave -position end sim:/tb_cpu_soc_ram_top/clk
add wave -position end sim:/tb_cpu_soc_ram_top/resetn
add wave -position end sim:/tb_cpu_soc_ram_top/pixel_clk


# =============================================================================
# GROUP 2: CPU NATIVE MEMORY BUS
# =============================================================================

add wave -divider "CPU NATIVE MEMORY BUS"

add wave -position end sim:/tb_cpu_soc_ram_top/dut/m_valid
add wave -position end sim:/tb_cpu_soc_ram_top/dut/m_write
add wave -position end sim:/tb_cpu_soc_ram_top/dut/m_addr
add wave -position end sim:/tb_cpu_soc_ram_top/dut/m_wdata
add wave -position end sim:/tb_cpu_soc_ram_top/dut/m_strb
add wave -position end sim:/tb_cpu_soc_ram_top/dut/m_ready
add wave -position end sim:/tb_cpu_soc_ram_top/dut/m_rdata


# =============================================================================
# GROUP 3: SOC MEMORY INTERCONNECT
# =============================================================================

add wave -divider "SOC MEMORY INTERCONNECT"

add wave -position end sim:/tb_cpu_soc_ram_top/dut/u_interconnect/m_valid
add wave -position end sim:/tb_cpu_soc_ram_top/dut/u_interconnect/m_write
add wave -position end sim:/tb_cpu_soc_ram_top/dut/u_interconnect/m_addr
add wave -position end sim:/tb_cpu_soc_ram_top/dut/u_interconnect/m_wdata
add wave -position end sim:/tb_cpu_soc_ram_top/dut/u_interconnect/m_strb
add wave -position end sim:/tb_cpu_soc_ram_top/dut/u_interconnect/m_ready
add wave -position end sim:/tb_cpu_soc_ram_top/dut/u_interconnect/m_rdata

add wave -position end sim:/tb_cpu_soc_ram_top/dut/u_interconnect/nn_sel

add wave -position end sim:/tb_cpu_soc_ram_top/dut/u_interconnect/nn_valid
add wave -position end sim:/tb_cpu_soc_ram_top/dut/u_interconnect/nn_write
add wave -position end sim:/tb_cpu_soc_ram_top/dut/u_interconnect/nn_addr
add wave -position end sim:/tb_cpu_soc_ram_top/dut/u_interconnect/nn_wdata
add wave -position end sim:/tb_cpu_soc_ram_top/dut/u_interconnect/nn_strb
add wave -position end sim:/tb_cpu_soc_ram_top/dut/u_interconnect/nn_ready
add wave -position end sim:/tb_cpu_soc_ram_top/dut/u_interconnect/nn_rdata


# =============================================================================
# GROUP 4: TPU MMIO / CONTROL
# =============================================================================

add wave -divider "TPU MMIO / CONTROL"

add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/axis_start
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/axis_busy
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/axis_done

add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/bus_req
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/bus_write
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/bus_addr
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/bus_wdata
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/bus_strb
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/bus_ready
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/bus_rdata


# =============================================================================
# GROUP 5: TPU WEIGHTS / INPUTS
# =============================================================================

add wave -divider "TPU WEIGHTS / INPUTS"

add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/weight0
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/weight1
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/weight2
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/weight3
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/weight4

add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/input0
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axi_wrapper/input1


# =============================================================================
# GROUP 6: AXI4-STREAM TX
#
# nn_axis_master -> axis_nn
# Transfer: m_axis_tvalid && m_axis_tready
# =============================================================================

add wave -divider "AXI4-STREAM TX"

add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/in_tvalid
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/in_tready
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/in_tdata
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/in_tlast


# =============================================================================
# GROUP 7: AXI4-STREAM RX
#
# axis_nn -> nn_axis_master
# Transfer: s_axis_tvalid && s_axis_tready
# =============================================================================

add wave -divider "AXI4-STREAM RX"

add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/out_tvalid
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/out_tready
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/out_tdata
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/out_tlast


# =============================================================================
# GROUP 8: AXIS MASTER FSM
# =============================================================================

add wave -divider "AXIS MASTER FSM"

add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/axis_start
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/axis_busy
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/axis_done

add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/state_reg
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/beat_reg

add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/m_axis_tvalid
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/m_axis_tready
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/m_axis_tdata
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/m_axis_tlast

add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/s_axis_tvalid
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/s_axis_tready
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/s_axis_tdata
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/s_axis_tlast

add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/result0
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_nn_axis_master/result1


# =============================================================================
# GROUP 9: AXIS NN ACCELERATOR
# =============================================================================

add wave -divider "AXIS NN ACCELERATOR"

add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/state_reg
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/mm2s_data_count
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/mm2s_ready_reg

add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/s_axis_tvalid
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/s_axis_tready
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/s_axis_tdata
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/s_axis_tlast

add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/m_axis_tvalid
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/m_axis_tready
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/m_axis_tdata
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/u_axis_nn/m_axis_tlast


# =============================================================================
# GROUP 10: TPU RESULTS
# =============================================================================

add wave -divider "TPU RESULTS"

add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/result0
add wave -position end sim:/tb_cpu_soc_ram_top/dut/tpu/result1

add wave -position end sim:/tb_cpu_soc_ram_top/dut/result0
add wave -position end sim:/tb_cpu_soc_ram_top/dut/result1


# =============================================================================
# GROUP 11: GPIO
# =============================================================================

add wave -divider "GPIO"

add wave -position end sim:/tb_cpu_soc_ram_top/dut/gpio_valid
add wave -position end sim:/tb_cpu_soc_ram_top/dut/gpio_write
add wave -position end sim:/tb_cpu_soc_ram_top/dut/gpio_addr
add wave -position end sim:/tb_cpu_soc_ram_top/dut/gpio_wdata
add wave -position end sim:/tb_cpu_soc_ram_top/dut/gpio_strb
add wave -position end sim:/tb_cpu_soc_ram_top/dut/gpio_ready
add wave -position end sim:/tb_cpu_soc_ram_top/dut/gpio_rdata


# =============================================================================
# GROUP 12: RAM
# =============================================================================

add wave -divider "RAM"

add wave -position end sim:/tb_cpu_soc_ram_top/dut/ram_valid
add wave -position end sim:/tb_cpu_soc_ram_top/dut/ram_write
add wave -position end sim:/tb_cpu_soc_ram_top/dut/ram_addr
add wave -position end sim:/tb_cpu_soc_ram_top/dut/ram_wdata
add wave -position end sim:/tb_cpu_soc_ram_top/dut/ram_strb
add wave -position end sim:/tb_cpu_soc_ram_top/dut/ram_ready
add wave -position end sim:/tb_cpu_soc_ram_top/dut/ram_rdata


# =============================================================================
# GROUP 13: RF
# =============================================================================

add wave -divider "RF"

add wave -position end sim:/tb_cpu_soc_ram_top/dut/rf_valid
add wave -position end sim:/tb_cpu_soc_ram_top/dut/rf_write
add wave -position end sim:/tb_cpu_soc_ram_top/dut/rf_addr
add wave -position end sim:/tb_cpu_soc_ram_top/dut/rf_wdata
add wave -position end sim:/tb_cpu_soc_ram_top/dut/rf_strb
add wave -position end sim:/tb_cpu_soc_ram_top/dut/rf_ready
add wave -position end sim:/tb_cpu_soc_ram_top/dut/rf_rdata


# =============================================================================
# GROUP 14: SENSOR
# =============================================================================

add wave -divider "SENSOR"

add wave -position end sim:/tb_cpu_soc_ram_top/dut/sensor_valid
add wave -position end sim:/tb_cpu_soc_ram_top/dut/sensor_write
add wave -position end sim:/tb_cpu_soc_ram_top/dut/sensor_addr
add wave -position end sim:/tb_cpu_soc_ram_top/dut/sensor_wdata
add wave -position end sim:/tb_cpu_soc_ram_top/dut/sensor_strb
add wave -position end sim:/tb_cpu_soc_ram_top/dut/sensor_ready
add wave -position end sim:/tb_cpu_soc_ram_top/dut/sensor_rdata


# =============================================================================
# GROUP 15: TESTBENCH OBSERVATION
# =============================================================================

add wave -divider "TESTBENCH OBSERVATION"

add wave -position end sim:/tb_cpu_soc_ram_top/trap

add wave -position end sim:/tb_cpu_soc_ram_top/gpio_in
add wave -position end sim:/tb_cpu_soc_ram_top/gpio_out
add wave -position end sim:/tb_cpu_soc_ram_top/gpio_oe

add wave -position end sim:/tb_cpu_soc_ram_top/rf_enable_o

add wave -position end sim:/tb_cpu_soc_ram_top/hsync_o
add wave -position end sim:/tb_cpu_soc_ram_top/vsync_o
add wave -position end sim:/tb_cpu_soc_ram_top/pixel_x_o
add wave -position end sim:/tb_cpu_soc_ram_top/pixel_y_o

add wave -position end sim:/tb_cpu_soc_ram_top/rgb_r_o
add wave -position end sim:/tb_cpu_soc_ram_top/rgb_g_o
add wave -position end sim:/tb_cpu_soc_ram_top/rgb_b_o


# =============================================================================
# 16. RUN SIMULATION
# =============================================================================

run -all


# =============================================================================
# 17. FIT WAVEFORM TO WINDOW
# =============================================================================

wave zoom full
