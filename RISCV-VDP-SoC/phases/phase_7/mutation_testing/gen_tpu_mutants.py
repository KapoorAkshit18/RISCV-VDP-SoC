import os

golden_path = '../fault_models/nn_axi_wrapper.v.golden'
mutant_dir = 'mutants/nn_axi_wrapper'

if not os.path.exists(golden_path):
    golden_path = '../fault_models/nn_axi_wrapper.v'

with open(golden_path, 'r') as f:
    golden_code = f.read()

# M_TPU_01
m1_code = golden_code.replace(
    'if (bus_strb[0] &&\n                            bus_wdata[0] &&',
    '''// GOLDEN: if (bus_strb[0] && bus_wdata[0] &&
// BUG M_TPU_01: CTRL START bit incorrectly ignored
if (bus_strb[0] &&
                            1\'b0 &&'''
)
with open(f'{mutant_dir}/M_TPU_01.v', 'w') as f: f.write(m1_code)

# M_TPU_02
m2_code = golden_code.replace(
    'else if (bus_addr[7:0] == REG_WEIGHT4_L) begin',
    '''// GOLDEN: else if (bus_addr[7:0] == REG_WEIGHT4_L) begin
// BUG M_TPU_02: One TPU weight register mapped to wrong offset
else if (bus_addr[7:0] == REG_WEIGHT3_L) begin'''
)
with open(f'{mutant_dir}/M_TPU_02.v', 'w') as f: f.write(m2_code)

# M_TPU_03
m3_code = golden_code.replace(
    'REG_INPUT0_L: bus_rdata = input0[31:0];',
    '''// GOLDEN: REG_INPUT0_L: bus_rdata = input0[31:0];
// BUG M_TPU_03: INPUT0 register readback incorrectly mapped to INPUT1
REG_INPUT0_L: bus_rdata = input1[31:0];'''
)
with open(f'{mutant_dir}/M_TPU_03.v', 'w') as f: f.write(m3_code)

# M_TPU_04
m4_code = golden_code.replace(
    'REG_RESULT0_L: bus_rdata = result0[31:0];',
    '''// GOLDEN: REG_RESULT0_L: bus_rdata = result0[31:0];
// BUG M_TPU_04: RESULT0 readback incorrectly routed to RESULT1
REG_RESULT0_L: bus_rdata = result1[31:0];'''
)
with open(f'{mutant_dir}/M_TPU_04.v', 'w') as f: f.write(m4_code)

# M_TPU_05
m5_code = golden_code.replace(
    'bus_rdata = {30\'d0, done_latched, axis_busy};',
    '''// GOLDEN: bus_rdata = {30\'d0, done_latched, axis_busy};
// BUG M_TPU_05: STATUS BUSY/DONE behavior incorrectly implemented (swapped)
                        bus_rdata = {30\'d0, axis_busy, done_latched};'''
)
with open(f'{mutant_dir}/M_TPU_05.v', 'w') as f: f.write(m5_code)
