# ============================================================
# RISCV-VDP-SoC (Phase 1 Baseline)
# Canonical RTL reference: Design_Dir/RTL
# ============================================================

+incdir+../../../Design_Dir/RTL
+incdir+./hdl_interconnect
+incdir+./RAM
+incdir+./riscv

# ------------------------------------------------------------
# RTL: Memory Interconnect (Canonical Design_Dir/RTL)
# ------------------------------------------------------------
../../../Design_Dir/RTL/soc_mem_interconnect.v

# ------------------------------------------------------------
# RTL: RAM (Canonical Design_Dir/RTL)
# ------------------------------------------------------------
../../../Design_Dir/RTL/soc_ram.v

# ------------------------------------------------------------
# RTL: RISC-V subsystem (Canonical Design_Dir/RTL)
# ------------------------------------------------------------
../../../Design_Dir/RTL/riscv.v
../../../Design_Dir/RTL/cpu_bus_adapter.v
../../../Design_Dir/RTL/cpu_soc_ram_top.v
../../../Design_Dir/RTL/riscv_wrapper.v

# ------------------------------------------------------------
# Testbench
# ------------------------------------------------------------
./hdl_interconnect/tb_soc_mem_interconnect.sv
tb_top.sv