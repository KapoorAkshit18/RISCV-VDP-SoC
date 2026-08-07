## ----------------------------------------------------------------------------
## System Clock (100 MHz from ZedBoard external oscillator)
## ----------------------------------------------------------------------------
set_property PACKAGE_PIN Y9 [get_ports {clk_0}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk_0}]
#create_clock -period 10.000 -name sys_clk_100m [get_ports {clk_0}]
## ----------------------------------------------------------------------------
## Resets (Mapped to ZedBoard Push Buttons for testing)
## ----------------------------------------------------------------------------
##set_property PACKAGE_PIN P16 [get_ports {resetn_0}]  ; # Center Button (BTNC)
#set_property PACKAGE_PIN T18 [get_ports {reset_rtl}] ; # Up Button (BTNU)
#set_property IOSTANDARD LVCMOS33 [get_ports {resetn_0}]
#set_property IOSTANDARD LVCMOS33 [get_ports {reset_rtl}]

## ----------------------------------------------------------------------------
## VGA Output Pins (Bank 33) - UPDATED WITH _0 SUFFIXES
## ----------------------------------------------------------------------------
set_property PACKAGE_PIN V20  [get_ports {rgb_r_o[0]}];   # VGA-R1
set_property PACKAGE_PIN U20  [get_ports {rgb_r_o[1]}];   # VGA-R2
set_property PACKAGE_PIN V19  [get_ports {rgb_r_o[2]}];   # VGA-R3
set_property PACKAGE_PIN V18  [get_ports {rgb_r_o[3]}];   # VGA-R4

set_property PACKAGE_PIN AB22 [get_ports {rgb_g_o[0]}];   # VGA-G1
set_property PACKAGE_PIN AA22 [get_ports {rgb_g_o[1]}];   # VGA-G2
set_property PACKAGE_PIN AB21 [get_ports {rgb_g_o[2]}];   # VGA-G3
set_property PACKAGE_PIN AA21 [get_ports {rgb_g_o[3]}];   # VGA-G4

set_property PACKAGE_PIN Y21  [get_ports {rgb_b_o[0]}];   # VGA-B1
set_property PACKAGE_PIN Y20  [get_ports {rgb_b_o[1]}];   # VGA-B2
set_property PACKAGE_PIN AB20 [get_ports {rgb_b_o[2]}];   # VGA-B3
set_property PACKAGE_PIN AB19 [get_ports {rgb_b_o[3]}];   # VGA-B4

set_property PACKAGE_PIN AA19 [get_ports {hsync_o}];  # VGA-HS
set_property PACKAGE_PIN Y19  [get_ports {vsync_o}];  # VGA-VS

set_property IOSTANDARD LVCMOS33 [get_ports {rgb_r_o[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_g_o[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_b_o[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hsync_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {vsync_o}]

## ----------------------------------------------------------------------------
## Clock Domain Crossing (CDC)
## Note: clk_out1_clk_wiz_0 is the default name Vivado gives the generated clock.
## If your timing report says it is named differently, update the name here.
## ----------------------------------------------------------------------------
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins cb_i/clk_wiz_0/clk_out2]] -group [get_clocks -of_objects [get_pins cb_i/clk_wiz_0/clk_out1]]
#set_clock_groups -asynchronous -group [get_clocks clk_out2_cb_clk_wiz_0_1_1] -group [get_clocks clk_out1_cb_clk_wiz_0_1_1]