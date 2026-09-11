# =============================================================================
# timing_synth.xdc
# Synthesis timing constraints for RISCV-VDP-SoC (cpu_soc_ram_top)
# Target: ZedBoard / Zynq-7000 (xc7z020clg484-1)
# =============================================================================

# 1. System Clock (100 MHz, 10.0 ns period)
create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]

# 2. VDP Pixel Clock (25 MHz, 40.0 ns period)
create_clock -period 40.000 -name pixel_clk -waveform {0.000 20.000} [get_ports pixel_clk]

# 3. Asynchronous Clock Domain Crossing (CDC) between System Clock and Pixel Clock
set_clock_groups -asynchronous -group [get_clocks clk] -group [get_clocks pixel_clk]

# 4. Out-of-context clock root buffer estimation
set_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports clk]
set_property HD.CLK_SRC BUFGCTRL_X0Y1 [get_ports pixel_clk]

