# run.do - Questa Sim script

# ------------------------------------------------------------
# SOC CLOCK / RESET
# ------------------------------------------------------------
add wave -divider "SOC CLOCK / RESET"
add wave sim:/tb_soc_ram_top/clk
add wave sim:/tb_soc_ram_top/resetn

# ------------------------------------------------------------
# CPU CORE INTERNALS
# ------------------------------------------------------------
add wave -divider "CPU CORE"
add wave -position insertpoint sim:/tb_soc_ram_top/dut/u_cpu/prv/reg_pc
add wave -position insertpoint sim:/tb_soc_ram_top/dut/u_cpu/prv/reg_next_pc
add wave -position insertpoint sim:/tb_soc_ram_top/dut/u_cpu/prv/count_cycle
add wave -position insertpoint sim:/tb_soc_ram_top/dut/u_cpu/prv/count_instr
add wave -position insertpoint sim:/tb_soc_ram_top/dut/u_cpu/prv/next_insn_opcode

# ------------------------------------------------------------
# CPU BUS
# ------------------------------------------------------------
add wave -divider "CPU BUS"
add wave sim:/tb_soc_ram_top/dut/mem_valid
add wave sim:/tb_soc_ram_top/dut/mem_instr
add wave sim:/tb_soc_ram_top/dut/mem_ready
add wave sim:/tb_soc_ram_top/dut/mem_addr
add wave sim:/tb_soc_ram_top/dut/mem_wdata
add wave sim:/tb_soc_ram_top/dut/mem_wstrb
add wave sim:/tb_soc_ram_top/dut/mem_rdata
add wave sim:/tb_soc_ram_top/dut/trap

# ------------------------------------------------------------
# SOC INTERCONNECT
# ------------------------------------------------------------
add wave -divider "SOC INTERCONNECT"
add wave sim:/tb_soc_ram_top/dut/m_valid
add wave sim:/tb_soc_ram_top/dut/m_write
add wave sim:/tb_soc_ram_top/dut/m_addr
add wave sim:/tb_soc_ram_top/dut/m_wdata
add wave sim:/tb_soc_ram_top/dut/m_strb
add wave sim:/tb_soc_ram_top/dut/m_ready
add wave sim:/tb_soc_ram_top/dut/m_rdata

# ------------------------------------------------------------
# RAM INTERCONNECT
# ------------------------------------------------------------
add wave -divider "RAM INTERCONNECT"
add wave sim:/tb_soc_ram_top/dut/ram_valid
add wave sim:/tb_soc_ram_top/dut/ram_write
add wave sim:/tb_soc_ram_top/dut/ram_addr
add wave sim:/tb_soc_ram_top/dut/ram_wdata
add wave sim:/tb_soc_ram_top/dut/ram_strb
add wave sim:/tb_soc_ram_top/dut/ram_ready
add wave sim:/tb_soc_ram_top/dut/ram_rdata

# ------------------------------------------------------------
# GPIO INTERCONNECT & I/O
# ------------------------------------------------------------
add wave -divider "GPIO INTERCONNECT"
add wave sim:/tb_soc_ram_top/dut/gpio_valid
add wave sim:/tb_soc_ram_top/dut/gpio_write
add wave sim:/tb_soc_ram_top/dut/gpio_addr
add wave sim:/tb_soc_ram_top/dut/gpio_wdata
add wave sim:/tb_soc_ram_top/dut/gpio_strb
add wave sim:/tb_soc_ram_top/dut/gpio_ready
add wave sim:/tb_soc_ram_top/dut/gpio_rdata

add wave -divider "GPIO I/O"
add wave sim:/tb_soc_ram_top/dut/gpio_in
add wave sim:/tb_soc_ram_top/dut/gpio_out
add wave sim:/tb_soc_ram_top/dut/gpio_oe

# ------------------------------------------------------------
# RF INTERCONNECT & I/O
# ------------------------------------------------------------
add wave -divider "RF INTERCONNECT"
add wave sim:/tb_soc_ram_top/dut/rf_valid
add wave sim:/tb_soc_ram_top/dut/rf_write
add wave sim:/tb_soc_ram_top/dut/rf_addr
add wave sim:/tb_soc_ram_top/dut/rf_wdata
add wave sim:/tb_soc_ram_top/dut/rf_strb
add wave sim:/tb_soc_ram_top/dut/rf_ready
add wave sim:/tb_soc_ram_top/dut/rf_rdata

add wave -divider "RF I/O"
add wave sim:/tb_soc_ram_top/dut/rssi_dbm_i
add wave sim:/tb_soc_ram_top/dut/link_up_i
add wave sim:/tb_soc_ram_top/dut/link_error_i
add wave sim:/tb_soc_ram_top/dut/carrier_detect_i
add wave sim:/tb_soc_ram_top/dut/rf_enable_o

# ------------------------------------------------------------
# SENSOR INTERCONNECT & I/O
# ------------------------------------------------------------
add wave -divider "SENSOR INTERCONNECT"
add wave sim:/tb_soc_ram_top/dut/sensor_valid
add wave sim:/tb_soc_ram_top/dut/sensor_write
add wave sim:/tb_soc_ram_top/dut/sensor_addr
add wave sim:/tb_soc_ram_top/dut/sensor_wdata
add wave sim:/tb_soc_ram_top/dut/sensor_strb
add wave sim:/tb_soc_ram_top/dut/sensor_ready
add wave sim:/tb_soc_ram_top/dut/sensor_rdata

add wave -divider "SENSOR I/O"
add wave sim:/tb_soc_ram_top/dut/battery_percent_i
add wave sim:/tb_soc_ram_top/dut/battery_voltage_mv_i
add wave sim:/tb_soc_ram_top/dut/sensor_valid_i

# ------------------------------------------------------------
# VDP INTERCONNECT & I/O
# ------------------------------------------------------------
add wave -divider "VDP INTERCONNECT"
add wave sim:/tb_soc_ram_top/dut/vdp_valid
add wave sim:/tb_soc_ram_top/dut/vdp_write
add wave sim:/tb_soc_ram_top/dut/vdp_addr
add wave sim:/tb_soc_ram_top/dut/vdp_wdata
add wave sim:/tb_soc_ram_top/dut/vdp_strb
add wave sim:/tb_soc_ram_top/dut/vdp_ready
add wave sim:/tb_soc_ram_top/dut/vdp_rdata

add wave -divider "VDP DISPLAY I/O"
add wave sim:/tb_soc_ram_top/dut/pixel_clk
add wave sim:/tb_soc_ram_top/dut/hsync_o
add wave sim:/tb_soc_ram_top/dut/vsync_o
add wave sim:/tb_soc_ram_top/dut/pixel_x_o
add wave sim:/tb_soc_ram_top/dut/pixel_y_o
add wave sim:/tb_soc_ram_top/dut/rgb_r_o
add wave sim:/tb_soc_ram_top/dut/rgb_g_o
add wave sim:/tb_soc_ram_top/dut/rgb_b_o

# ------------------------------------------------------------
# RUN SIMULATION
# ------------------------------------------------------------
run 5000 us

# quit -sim