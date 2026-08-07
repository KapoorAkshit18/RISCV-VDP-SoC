# ----------------------------------------------------------------------------
# 1. Clock and Reset Constraints
# ----------------------------------------------------------------------------
# 100 MHz System Clock (ZedBoard Pin Y9)
#set_property PACKAGE_PIN Y9 [get_ports {sys_clock}]
#set_property IOSTANDARD LVCMOS33 [get_ports {sys_clock}]
#create_clock -period 10.000 -name sys_clock_pin -waveform {0.000 5.000} -add [get_ports {sys_clock}]

# External Reset (Mapped to the Center Push Button 'BTNC' - Pin P16)
set_property PACKAGE_PIN P16 [get_ports {reset_rtl}]
set_property IOSTANDARD LVCMOS25 [get_ports {reset_rtl}]

# ----------------------------------------------------------------------------
# 2. VGA Output Constraints (12-bit Color + Sync)
# ----------------------------------------------------------------------------
# RED Channel [3:0]
set_property PACKAGE_PIN V20 [get_ports {rgb_r_o[0]}]
set_property PACKAGE_PIN U20 [get_ports {rgb_r_o[1]}]
set_property PACKAGE_PIN V19 [get_ports {rgb_r_o[2]}]
set_property PACKAGE_PIN V18 [get_ports {rgb_r_o[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_r_o[*]}]

# GREEN Channel [3:0]
set_property PACKAGE_PIN AB22 [get_ports {rgb_g_o[0]}]
set_property PACKAGE_PIN AA22 [get_ports {rgb_g_o[1]}]
set_property PACKAGE_PIN AB21 [get_ports {rgb_g_o[2]}]
set_property PACKAGE_PIN AA21 [get_ports {rgb_g_o[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_g_o[*]}]

# BLUE Channel [3:0]
set_property PACKAGE_PIN Y21 [get_ports {rgb_b_o[0]}]
set_property PACKAGE_PIN Y20 [get_ports {rgb_b_o[1]}]
set_property PACKAGE_PIN AB20 [get_ports {rgb_b_o[2]}]
set_property PACKAGE_PIN AB19 [get_ports {rgb_b_o[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_b_o[*]}]

# HSYNC and VSYNC
set_property PACKAGE_PIN AA19 [get_ports {hsync_o}]
set_property PACKAGE_PIN Y19 [get_ports {vsync_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {hsync_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {vsync_o}]

# ----------------------------------------------------------------------------
# 3. Clock Domain Crossing (Timing Constraints)
# ----------------------------------------------------------------------------
# Tells Vivado to safely ignore timing analysis between the 100MHz (clk_out2) 
# and 25MHz (clk_out1) clock domains to resolve Critical Warnings.
# Note: The "-hierarchical" flag ensures it finds the clocking wizard pins 
# regardless of what your block design wrapper is named.



