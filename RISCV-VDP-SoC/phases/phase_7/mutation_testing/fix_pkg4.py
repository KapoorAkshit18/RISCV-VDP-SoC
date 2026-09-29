with open('c:/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_5/Old2New_SoC/Tb/UVM/tb/soc_pkg/soc_uvm_pkg.sv', 'r') as f:
    lines = f.readlines()

clean_lines = [l for l in lines if 'include "soc_base_test/soc_active_tpu_ral_test.sv"' not in l]

for i, l in enumerate(clean_lines):
    if 'soc_active_vdp_ral_test.sv' in l:
        clean_lines.insert(i+1, '    `include "soc_base_test/soc_active_tpu_ral_test.sv"\n')
        break

with open('c:/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_5/Old2New_SoC/Tb/UVM/tb/soc_pkg/soc_uvm_pkg.sv', 'w') as f:
    f.writelines(clean_lines)
