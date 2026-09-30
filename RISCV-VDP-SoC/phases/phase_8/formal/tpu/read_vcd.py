import sys
import re

def parse_vcd(filename, signals):
    with open(filename, 'r') as f:
        data = f.read()
    
    # Very rudimentary VCD parsing
    sig_map = {}
    for line in data.split('\n'):
        if line.startswith(''):
            parts = line.split()
            name = parts[4]
            symbol = parts[3]
            for s in signals:
                if name == s:
                    sig_map[symbol] = name
                    
    print('Found symbols:', sig_map)
    time = 0
    vals = {s: 'x' for s in sig_map.values()}
    
    for line in data.split('\n'):
        if line.startswith('#'):
            time = int(line[1:])
        elif line.startswith('b'):
            val, symbol = line[1:].split(' ')
            if symbol in sig_map:
                vals[sig_map[symbol]] = val
                print(f'Time {time}: {sig_map[symbol]} = {val}')
        elif len(line) == 2 and line[1] in sig_map:
            vals[sig_map[line[1]]] = line[0]
            print(f'Time {time}: {sig_map[line[1]]} = {line[0]}')

parse_vcd('phases/phase_8/formal/tpu/p05_results/fail_prop5.vcd', ['axis_start', 'm_axis_tvalid', 'start_request', 'past_valid'])
