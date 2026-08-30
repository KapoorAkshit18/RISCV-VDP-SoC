.PHONY: all compile run run_gui clean

all: compile run

compile:
	vlib work
	vlog -sv -f filelist.f

run:
	vsim -c -voptargs="+acc" work.tb_soc_mem_interconnect -do run.do

run_gui:
	vsim -voptargs="+acc" work.tb_soc_mem_interconnect -do run.do

clean:
	rm -rf work transcript *.wlf modelsim.ini