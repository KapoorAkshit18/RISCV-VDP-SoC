with open('c:/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_5/Old2New_SoC/Tb/UVM/tb/soc_pkg/soc_uvm_pkg.sv', 'r') as f:
    lines = f.readlines()

for i, l in enumerate(lines):
    if 'soc_ral/vdp_reg_block.sv' in l:
        lines.insert(i+1, '      include "soc_ral/tpu_reg_block.sv"\n')
        break

with open('c:/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_5/Old2New_SoC/Tb/UVM/tb/soc_pkg/soc_uvm_pkg.sv', 'w') as f:
    f.writelines(lines)
