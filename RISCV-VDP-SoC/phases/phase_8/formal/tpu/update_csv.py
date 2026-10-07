import csv

# Read cover results
cover_data = {}
with open('tpu_p05_cover_results.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        depth = row['depth']
        res = row['result']
        if res == 'PASS':
            cover_data[depth] = 'PASS (2 traces: step 3, step 4)'
        elif res == 'UNREACHABLE':
            cover_data[depth] = f'UNREACHABLE (depth {depth} < min latency)'
        else:
            cover_data[depth] = res

# Read and update formal results
updated_rows = []
with open('tpu_p05_control_formal_results.csv', 'r') as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames
    for row in reader:
        depth = row['depth']
        if depth in cover_data:
            row['covers'] = cover_data[depth]
        updated_rows.append(row)

with open('tpu_p05_control_formal_results.csv', 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(updated_rows)

print(
