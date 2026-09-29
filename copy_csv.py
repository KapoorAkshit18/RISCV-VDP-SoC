import csv

input_file = r'c:\RISCV-VDP-SoC\RISCV-VDP-SoC\phases\phase_7\mutation_testing\results\mutation_results_new.csv'
output_file = r'c:\RISCV-VDP-SoC\RISCV-VDP-SoC\phases\phase_7\mutation_testing\results\mutation_results.csv'

with open(input_file, 'r', newline='') as infile, open(output_file, 'w', newline='') as outfile:
    reader = csv.reader(infile)
    writer = csv.writer(outfile)
    for row in reader:
        writer.writerow(row)
