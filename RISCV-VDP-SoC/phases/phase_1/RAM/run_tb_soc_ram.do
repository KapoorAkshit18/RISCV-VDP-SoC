# Compile DUT and Testbench
vlog soc_ram.v
vlog tb_soc_ram.sv

# Elaborate the testbench
vsim work.tb_soc_ram

# Wait until vsim has loaded before adding waves
# (this ensures hierarchy is available)
quietly add wave sim:/tb_soc_ram/*
quietly add wave -r sim:/tb_soc_ram/dut/*

# Run simulation
run -all
