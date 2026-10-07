import csv

cover_data = {}
with open('tpu_p05_cover_results.csv', 'r') as f:
    for row in csv.DictReader(f):
        d = row['depth']
        res = row['result']
        if res == 'PASS':
            cover_data[d] = 'PASS (step 3, 4)'
        elif res == 'UNREACHABLE':
            cover_data[d] = f'UNREACHABLE (depth {d} < min)'
        else:
            cover_data[d] = res

rows = []
with open('tpu_p05_control_formal_results.csv', 'r') as f:
    reader = csv.DictReader(f)
    fields = reader.fieldnames
    for r in reader:
        d = r['depth']
        if d in cover_data:
            r['covers'] = cover_data[d]
        rows.append(r)

with open('tpu_p05_control_formal_results.csv', 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=fields)
    writer.writeheader()
    writer.writerows(rows)

print('Updated successfully')
