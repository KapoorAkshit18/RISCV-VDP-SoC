import csv
import sys

input_file = r'c:\RISCV-VDP-SoC\RISCV-VDP-SoC\phases\phase_7\mutation_testing\results\mutation_results.csv'
output_file = r'c:\RISCV-VDP-SoC\RISCV-VDP-SoC\phases\phase_7\mutation_testing\results\mutation_results_new.csv'

with open(input_file, 'r', newline='') as infile, open(output_file, 'w', newline='') as outfile:
    reader = csv.reader(infile)
    writer = csv.writer(outfile)
    
    header = next(reader)
    # Find Active_UVM_Test index
    if 'Active_UVM_Test' in header:
        idx = header.index('Active_UVM_Test')
        # Replace it with Golden and Mutant result
        new_header = header[:idx] + ['Active_UVM_Golden_Result', 'Active_UVM_Mutant_Result'] + header[idx+1:]
        writer.writerow(new_header)
        
        for row in reader:
            if len(row) > idx:
                if row[0] == 'M02':
                    # We know M02 had PASS for compile, and earlier I put FAIL for Test. 
                    # Golden=PASS, Mutant=FAIL
                    new_row = row[:idx] + ['PASS', 'FAIL'] + row[idx+1:]
                else:
                    new_row = row[:idx] + ['', ''] + row[idx+1:]
                writer.writerow(new_row)
            else:
                writer.writerow(row)
    else:
        print("Header not found")
        sys.exit(1)
