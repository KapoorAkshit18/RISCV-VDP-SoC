with open('c:/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_5/Old2New_SoC/Tb/UVM/tb/soc_ral/soc_reg_block.sv', 'r') as f:
    lines = f.readlines()

tpu_build = '''
        // ====================================================
        // Create TPU RAL block
        // ====================================================

        tpu = tpu_reg_block::type_id::create(\"tpu\");
        tpu.configure(this);
        tpu.build();

'''
lines.insert(98, tpu_build)

tpu_map = '''
        // TPU
        // 0x0001_4000 - 0x0001_4FFF

        default_map.add_submap(
            tpu.default_map,
            32'h0001_4000
        );

'''
for i, l in enumerate(lines):
    if 'Lock complete RAL model' in l:
        lines.insert(i-1, tpu_map)
        break

with open('c:/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_5/Old2New_SoC/Tb/UVM/tb/soc_ral/soc_reg_block.sv', 'w') as f:
    f.writelines(lines)
