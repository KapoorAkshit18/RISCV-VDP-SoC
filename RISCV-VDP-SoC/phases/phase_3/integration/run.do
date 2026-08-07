# run.do - Questa Sim script

# Add waves to the waveform viewer
#add wave -position insertpoint sim:/tb_soc_ram_top/*

#gpio
add wave -divider "SOC CLOCK/RESET"
add wave sim:/tb_soc_ram_top/clk
add wave sim:/tb_soc_ram_top/resetn

add wave -divider "CPU BUS"
add wave sim:/tb_soc_ram_top/dut/mem_valid
add wave sim:/tb_soc_ram_top/dut/mem_ready
add wave sim:/tb_soc_ram_top/dut/mem_addr
add wave sim:/tb_soc_ram_top/dut/mem_wdata
add wave sim:/tb_soc_ram_top/dut/mem_wstrb
add wave sim:/tb_soc_ram_top/dut/mem_rdata

add wave -divider "SOC INTERCONNECT"
add wave sim:/tb_soc_ram_top/dut/m_valid
add wave sim:/tb_soc_ram_top/dut/m_write
add wave sim:/tb_soc_ram_top/dut/m_addr
add wave sim:/tb_soc_ram_top/dut/m_wdata
add wave sim:/tb_soc_ram_top/dut/m_strb
add wave sim:/tb_soc_ram_top/dut/m_ready
add wave sim:/tb_soc_ram_top/dut/m_rdata

add wave -divider "GPIO"
add wave sim:/tb_soc_ram_top/dut/gpio_valid
add wave sim:/tb_soc_ram_top/dut/gpio_write
add wave sim:/tb_soc_ram_top/dut/gpio_addr
add wave sim:/tb_soc_ram_top/dut/gpio_wdata
add wave sim:/tb_soc_ram_top/dut/gpio_strb
add wave sim:/tb_soc_ram_top/dut/gpio_ready
add wave sim:/tb_soc_ram_top/dut/gpio_rdata

add wave -divider "GPIO OUTPUTS"
add wave sim:/tb_soc_ram_top/dut/gpio_out
add wave sim:/tb_soc_ram_top/dut/gpio_oe


# Run the simulation to completion
run 5000 us

# Exit if running in batch mode (uncomment if you want it to auto-close)
# quit -sim