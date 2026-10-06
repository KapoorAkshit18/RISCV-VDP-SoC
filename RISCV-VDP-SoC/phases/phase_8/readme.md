# Final Summary of the Project 

RTL / Design

soc_mem_interconnect.v — combinational native-bus interconnect, address map: RAM 0x0000_0000, GPIO 0x0001_0000, RF 0x0001_1000, Sensor 0x0001_2000, VDP 0x0001_3000, TPU 0x0001_4000, all 4KB peripheral windows

cpu_bus_adapter.v — thin adapter mapping PicoRV32 mem_wstrb to native bus m_write/m_strb

vdp_native_slave.v — VDP peripheral with dual clock domains (system clk + pixel_clk), Gray-code CDC for HCOUNT/VCOUNT, toggle-handshake CDC for config, RGB444 VGA output

Verification Environment

UVM agent: soc_sequence_item.sv, sequencer, driver, monitor, env

RAL blocks: gpio_reg_block.sv, rf_reg_block.sv, sensor_reg_block.sv, vdp_reg_block.sv, soc_reg_block.sv, soc_reg_adapter.sv, soc_reg_predictor.sv

Scoreboard: soc_tpu_scoreboard.sv with C DPI reference model (tpu_ref_model.c)

Coverage: soc_coverage.sv — 100% functional coverage, 48/48 bins hit

Mutation Testing (Phase 7)

10 SoC interconnect mutants (M01–M10), 5 TPU mutants (M_TPU_01–05)

2 equivalent mutants: M05 (vdp_write), M09 (RAM addr LSBs)

13 viable mutations — all detected by Active UVM

Directed FW: detected 2/8 SoC viable, 4/5 TPU

Passive UVM: same as Directed

Active UVM: detected all 13 viable

Formal Verification (Phase 8)

Tool: SymbiYosys, SMT-BMC, Z3 solver

Sensor: 8 properties — all PASS (SEN_AS01, SEN_A01–A04, SEN_C01_C08)

CPU/RAM: ABS_A01 — PASS

Interconnect + TPU: TIMEOUT (Z3 state-space bottleneck)

Coverage

100% functional coverage: 48/48 bins, 6 targets, all read/write/strobe combinations

Firmware / Performance

Sigmoid firmware baseline: 1343 cycles

TPU integration: 372 cycles → 3.61× speedup

TPU transaction breakdown: 7-cycle TX, 58-cycle compute, 2-cycle RX = 67 cycles total
