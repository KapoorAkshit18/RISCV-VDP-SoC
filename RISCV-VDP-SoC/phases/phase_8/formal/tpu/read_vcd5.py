import sys
with open('p05_results/out_prop_1_depth_4_new/engine_0/trace.vcd', 'r') as f:
    text = f.read()

sig_map = {
    'n18': 'axis_busy',
    'n19': 'axis_start',
    'n28': 'init',
    'n32': 'past_valid',
    'n33': 'rst_n',
    'n34': 'start_request',
    'n20': 'bus_addr',
    'n21': 'bus_req',
    'n22': 'bus_strb',
    'n24': 'bus_wdata',
    'n26': 'bus_write',
    'n29': 'is_control_reg'
}

time = '0'
for line in text.split('\n'):
    if line.startswith('#'):
        time = line[1:]
        print(f'\n--- Time {time} ---')
    elif line.startswith('b'):
        parts = line.split()
        if len(parts) >= 2 and parts[1] in sig_map:
            print(f'{sig_map[parts[1]]} = {parts[0][1:]}')
    elif len(line) >= 2 and line[1:] in sig_map:
        print(f'{sig_map[line[1:]]} = {line[0]}')
