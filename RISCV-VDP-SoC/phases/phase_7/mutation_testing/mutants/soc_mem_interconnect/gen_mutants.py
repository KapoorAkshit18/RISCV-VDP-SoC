import os

golden_path = r"c:\RISCV-VDP-SoC\RISCV-VDP-SoC\phases\phase_7\fault_models\soc_mem_interconnect.v"
out_dir = r"c:\RISCV-VDP-SoC\RISCV-VDP-SoC\phases\phase_7\mutation_testing\mutants\soc_mem_interconnect"

os.makedirs(out_dir, exist_ok=True)

with open(golden_path, "r") as f:
    content = f.read()

# M06
m06 = content.replace("ram_strb  = m_strb;",
                      "// GOLDEN: ram_strb = m_strb;\n                // BUG M06: Intentional mutation — strobe propagation error.\n                // RAM byte strobe forced to 4'hF, ignoring actual byte enables from master.\n                ram_strb  = 4'hF;")
with open(os.path.join(out_dir, "M06_strobe_prop.v"), "w") as f: f.write(m06)

# M07
m07 = content.replace("rf_valid = 1'b1;",
                      "// GOLDEN: rf_valid = 1'b1;\n                // BUG M07: Intentional mutation — incorrect peripheral valid assertion.\n                // RF valid stuck at 0, RF slave never sees valid transactions.\n                rf_valid = 1'b0;")
with open(os.path.join(out_dir, "M07_periph_valid.v"), "w") as f: f.write(m07)

# M08
m08 = content.replace("assign sensor_sel =\n        ((m_addr & PERIPH_MASK) == SENSOR_BASE);",
                      "// GOLDEN: assign sensor_sel = ((m_addr & PERIPH_MASK) == SENSOR_BASE);\n    // BUG M08: Intentional mutation — incorrect peripheral address-window decode.\n    // Sensor decode compares against VDP_BASE instead of SENSOR_BASE.\n    assign sensor_sel =\n        ((m_addr & PERIPH_MASK) == VDP_BASE);")
with open(os.path.join(out_dir, "M08_addr_window.v"), "w") as f: f.write(m08)

# M09
m09 = content.replace("ram_addr  = m_addr;",
                      "// GOLDEN: ram_addr = m_addr;\n                // BUG M09: Intentional mutation — RAM address corruption.\n                // Lowest 2 bits of RAM address forced to 0, breaking byte-level addressing.\n                ram_addr  = {m_addr[31:2], 2'b00};")
with open(os.path.join(out_dir, "M09_ram_addr.v"), "w") as f: f.write(m09)

# M10
m10 = content.replace("            else begin\n\n                m_ready = 1'b1;\n                m_rdata = {DATA_WIDTH{1'b0}};\n\n            end",
                      "            else begin\n\n                // GOLDEN: m_ready = 1'b1;\n                // BUG M10: Intentional mutation — incorrect unmapped-access completion.\n                // Unmapped accesses never signal ready, causing bus hang.\n                m_ready = 1'b0;\n                m_rdata = {DATA_WIDTH{1'b0}};\n\n            end")
with open(os.path.join(out_dir, "M10_unmapped.v"), "w") as f: f.write(m10)
