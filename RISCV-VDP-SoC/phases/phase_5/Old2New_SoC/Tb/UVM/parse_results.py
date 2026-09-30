import csv
import glob
import re

rows = []

for logfile in sorted(glob.glob("run_*.log")):

    with open(logfile, "r", errors="ignore") as f:
        text = f.read()

    # CONFIG,seed,temp_c,batt,noise_on
    m = re.search(
        r"CONFIG,\s*([^,\s]+),\s*([^,\s]+),\s*([^,\s]+),\s*([^,\s]+)",
        text
    )

    if not m:
        print(f"WARNING: CONFIG not found in {logfile}")
        continue

    seed = m.group(1)
    temp_c_in = float(m.group(2))
    batt = m.group(3)
    noise_on = m.group(4)

    # RNMLOG,adc_code,sensor_voltage,...
    m = re.search(
        r"RNMLOG,\s*([^,\s]+),\s*([^,\s]+)",
        text
    )

    adc_code = m.group(1) if m else ""
    sensor_voltage = m.group(2) if m else ""

    # SENSORLOG,TEMP,<temp_read_tenths>
    m = re.search(
        r"SENSORLOG,TEMP,\s*([^,\s]+)",
        text
    )

    temp_read_tenths = int(m.group(1)) if m else ""

    # ideal_tenths = round(temp_c_in * 10)
    ideal_tenths = round(temp_c_in * 10)

    # error = actual - ideal
    error = (
        temp_read_tenths - ideal_tenths
        if temp_read_tenths != ""
        else ""
    )

    # ALARM,TEMP,expected,actual  and  ALARM,BATT,expected,actual
    # Two real model-vs-RTL comparisons (not just bus-passthrough sanity
    # checks like temp_read_tenths/adc_code, which are trivially ~1.0).
    m = re.search(
        r"ALARM,TEMP,\s*([^,\s]+),\s*([^,\s]+)",
        text
    )
    # for grouping 
    
    temp_alarm_exp = m.group(1) if m else ""
    temp_alarm_act = m.group(2) if m else ""

    m = re.search(
        r"ALARM,BATT,\s*([^,\s]+),\s*([^,\s]+)",
        text
    )
    batt_alarm_exp = m.group(1) if m else ""
    batt_alarm_act = m.group(2) if m else ""

    # Final result
    matches = re.findall(
        r"\[PASS\]|\[FAIL\]|SUCCESS marker|reported ERROR",
        text
    )

    result = matches[-1] if matches else ""

    rows.append([
        seed,
        temp_c_in,
        batt,
        noise_on,
        adc_code,
        sensor_voltage,
        temp_read_tenths,
        ideal_tenths,
        error,
        temp_alarm_exp,
        temp_alarm_act,
        batt_alarm_exp,
        batt_alarm_act,
        result
    ])


with open("results.csv", "w", newline="") as f:

    writer = csv.writer(f)

    writer.writerow([
        "seed",
        "temp_c_in",
        "batt",
        "noise_on",
        "adc_code",
        "sensor_voltage",
        "temp_read_tenths",
        "ideal_tenths",
        "error",
        "temp_alarm_exp",
        "temp_alarm_act",
        "batt_alarm_exp",
        "batt_alarm_act",
        "result"
    ])

    writer.writerows(rows)

print(f"Wrote results.csv ({len(rows)} test points)")