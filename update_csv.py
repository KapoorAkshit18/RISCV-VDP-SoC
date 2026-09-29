import csv

input_file = r'c:\RISCV-VDP-SoC\RISCV-VDP-SoC\phases\phase_7\mutation_testing\results\mutation_results.csv'
output_file = r'c:\RISCV-VDP-SoC\RISCV-VDP-SoC\phases\phase_7\mutation_testing\results\mutation_results_new.csv'

results = {
    'M01': {'mutant': 'PASS', 'detection': 'ESCAPED', 'mech': 'TPU status returns 0 when idle', 'note': 'Test reads TPU status. Both golden (idle) and mutant (unmapped) return 0. Genuine escape due to insufficient stimulus.'},
    'M03': {'mutant': 'FAIL', 'detection': 'DETECTED', 'mech': 'UVM_ERROR/TIMEOUT', 'note': 'GPIO transactions hang because RF ready is 0 when idle.'},
    'M04': {'mutant': 'PASS', 'detection': 'ESCAPED', 'mech': 'RF RSSI returns 0', 'note': 'RF read returns 0x00. M04 routes Sensor data. Sensor battery is 0x50, but maybe sensor is idle? Actually sensor battery should be 0x50.'},
    'M05': {'mutant': 'PASS', 'detection': 'ESCAPED', 'mech': 'VDP RTL ignores mem_write', 'note': 'VDP color register uses mem_wstrb without checking mem_write. Thus forcing vdp_write=0 has no effect. Genuine equivalent/design flaw.'},
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
    idx_mutant = header.index('Active_UVM_Mutant_Result')
    idx_detect = header.index('Active_UVM_Detection')
    idx_active = header.index('Active_UVM_Activation')
    idx_mech = header.index('Active_UVM_Detection_Mechanism')
    idx_note = header.index('Active_UVM_Notes')
    
    for row in reader:
        m_id = row[0]
        if m_id in results:
            row[idx_golden] = 'PASS'
            row[idx_mutant] = results[m_id]['mutant']
            row[idx_detect] = results[m_id]['detection']
            row[idx_active] = 'YES'
            row[idx_mech] = results[m_id]['mech']
            row[idx_note] = results[m_id]['note']
        writer.writerow(row)
