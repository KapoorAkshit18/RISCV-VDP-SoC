# ============================================================
# RISCV-VDP-SoC
# CPU -> Adapter -> Memory Interconnect -> RAM
# ============================================================

+incdir+./hdl_interconnect
+incdir+./RAM
+incdir+./riscv



# ------------------------------------------------------------
# RTL: Memory Interconnect
# ------------------------------------------------------------
./hdl_interconnect/soc_mem_interconnect.v

# ------------------------------------------------------------
# RTL: RAM
# ------------------------------------------------------------
./RAM/soc_ram.v

# ------------------------------------------------------------
# RTL: RISC-V subsystem
# ------------------------------------------------------------
./riscv/rtl/riscv.v
./riscv/rtl/cpu_bus_adapter.v
./riscv/rtl/cpu_soc_ram_top.v
./riscv/rtl/riscv_wrapper.sv

# ------------------------------------------------------------
# Testbench
# ------------------------------------------------------------
./hdl_interconnect/tb_soc_mem_interconnect.sv