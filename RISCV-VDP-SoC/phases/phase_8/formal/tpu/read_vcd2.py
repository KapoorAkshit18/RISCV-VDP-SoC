import sys
with open('p05_results/out_prop_1_depth_4_new/engine_0/trace.vcd', 'r') as f:
    text = f.read()

sig_map = {'n16': 'axis_start', 'n15': 'axis_busy', 'n29': 'start_request', 'n28': 'rst_n'}

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
