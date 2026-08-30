.PHONY: all compile run run_gui clean

all: compile run

compile:
	# Create the working library
	vlib work
	# Compile the design and testbench files
	vlog -sv -f filelist.f

run:
	# Run simulation in command-line mode
	vsim -c -voptargs="+acc" work.tb_cpu_ram_subsystem -do run.do

run_gui:
	# Run simulation in GUI mode
	vsim -voptargs="+acc" work.tb_cpu_ram_subsystem -do run.do

clean:
	rm -rf work transcript *.wlf modelsim.ini