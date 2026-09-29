import csv

input_file = r'c:\RISCV-VDP-SoC\RISCV-VDP-SoC\phases\phase_7\mutation_testing\results\mutation_results.csv'
output_file = r'c:\RISCV-VDP-SoC\RISCV-VDP-SoC\phases\phase_7\mutation_testing\results\mutation_results_new.csv'

results = {
    'M01': {'mutant': 'PASS', 'detection': 'ESCAPED', 'mech': 'TPU status returns 0 when idle', 'note': 'Test reads TPU status. Both golden (idle) and mutant (unmapped) return 0.'},
    'M03': {'mutant': 'FAIL', 'detection': 'DETECTED', 'mech': 'UVM_ERROR/TIMEOUT', 'note': 'GPIO transactions hang because RF ready is 0 when idle.'},
    'M04': {'mutant': 'PASS', 'detection': 'ESCAPED', 'mech': 'RF RSSI returns 0', 'note': 'RF read returns 0x00. M04 routes Sensor data, but maybe unmapped.'},
    'M05': {'mutant': 'PASS', 'detection': 'ESCAPED', 'mech': 'VDP RTL ignores mem_write', 'note': 'VDP color register uses mem_wstrb without checking mem_write. Forcing vdp_write=0 has no effect.'},
    'M06': {'mutant': 'FAIL', 'detection': 'DETECTED', 'mech': 'UVM_ERROR on RAM readback', 'note': 'RAM sub-word access corrupted by forced 4hF strobe.'},
    'M07': {'mutant': 'FAIL', 'detection': 'DETECTED', 'mech': 'UVM_ERROR/TIMEOUT', 'note': 'RF transactions hang due to forced 0 valid.'},
    'M08': {'mutant': 'FAIL', 'detection': 'DETECTED', 'mech': 'UVM_ERROR', 'note': 'Sensor accesses aliased to VDP/Unmapped.'},
    'M09': {'mutant': 'PASS', 'detection': 'ESCAPED', 'mech': 'Equivalent mutant', 'note': 'Word-aligned RAM ignores bottom 2 bits anyway.'},
    'M10': {'mutant': 'FAIL', 'detection': 'DETECTED', 'mech': 'UVM_ERROR/TIMEOUT', 'note': 'Unmapped reads hang the bus.'}
}

with open(input_file, 'r', newline='') as infile, open(output_file, 'w', newline='') as outfile:
    reader = csv.reader(infile)
    writer = csv.writer(outfile)
    
    header = next(reader)
    writer.writerow(header)
    
    idx_golden = header.index('Active_UVM_Golden_Result')
    
    for row in reader:
        m_id = row[0]
        # Pad row if necessary
        while len(row) < len(header):
            row.append('')
            
        if m_id in results:
            row[header.index('Active_UVM_Golden_Result')] = 'PASS'
            row[header.index('Active_UVM_Mutant_Result')] = results[m_id]['mutant']
            row[header.index('Active_UVM_Detection')] = results[m_id]['detection']
            row[header.index('Active_UVM_Activation')] = 'YES'
            row[header.index('Active_UVM_Detection_Mechanism')] = results[m_id]['mech']
            row[header.index('Active_UVM_Notes')] = results[m_id]['note']
        writer.writerow(row)
