import csv
import os

out_file = 'phases/phase_8/formal/tpu/master_formal_results.csv'
headers = ['experiment', 'property', 'boundary', 'depth', 'result', 'runtime_sec', 'mutation', 'counterexample', 'notes']

with open(out_file, 'w', newline='') as f_out:
    writer = csv.DictWriter(f_out, fieldnames=headers)
    writer.writeheader()

    # 1. tpu_formal_decomposition.csv
    try:
        with open('phases/phase_8/formal/tpu/tpu_formal_decomposition.csv', 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                writer.writerow({
                    'experiment': 'Decomposition',
                    'property': row.get('property_id', ''),
                    'boundary': row.get('target', ''),
                    'depth': row.get('depth', ''),
                    'result': row.get('result', ''),
                    'runtime_sec': row.get('runtime_seconds', ''),
                    'mutation': 'NO',
                    'counterexample': row.get('counterexample', ''),
                    'notes': row.get('notes', '')
                })
    except FileNotFoundError:
        pass

    # 2. tpu_p05_control_formal_results.csv
    try:
        with open('phases/phase_8/formal/tpu/tpu_p05_control_formal_results.csv', 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                writer.writerow({
                    'experiment': 'Control_Boundary',
                    'property': row.get('property', ''),
                    'boundary': row.get('boundary', ''),
                    'depth': row.get('depth', ''),
                    'result': row.get('result', ''),
                    'runtime_sec': row.get('runtime_sec', ''),
                    'mutation': 'NO',
                    'counterexample': row.get('counterexample', ''),
                    'notes': row.get('notes', '')
                })
    except FileNotFoundError:
        pass

    # 3. tpu_mutation_formal_results.csv
    try:
        with open('phases/phase_8/formal/tpu/tpu_mutation_formal_results.csv', 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                writer.writerow({
                    'experiment': 'Mutation_Testing',
                    'property': row.get('property_id', ''),
                    'boundary': 'tpu_interface_formal',
                    'depth': '10',
                    'result': row.get('mutant_result', ''),
                    'runtime_sec': '',
                    'mutation': row.get('mutant', ''),
                    'counterexample': row.get('counterexample_detected', ''),
                    'notes': row.get('notes', '')
                })
    except FileNotFoundError:
        pass

    # 4. tpu_p05_control_mutation_results.csv
    try:
        with open('phases/phase_8/formal/tpu/tpu_p05_control_mutation_results.csv', 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                writer.writerow({
                    'experiment': 'Control_Mutation',
                    'property': row.get('property', ''),
                    'boundary': row.get('boundary', ''),
                    'depth': row.get('depth', ''),
                    'result': row.get('result', ''),
                    'runtime_sec': row.get('runtime_sec', ''),
                    'mutation': row.get('mutation', ''),
                    'counterexample': row.get('counterexample', ''),
                    'notes': row.get('notes', '')
                })
    except FileNotFoundError:
        pass
