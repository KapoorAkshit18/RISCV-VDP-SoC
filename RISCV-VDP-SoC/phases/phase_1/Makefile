compile:
	vlog -f filelist.f

sim:
	vsim -c -do "run -all; quit" tb_cpu_ram_subsystem

clean:
	rm -rf work
	rm -rf transcript
	rm -rf vsim.wlf
	rm -rf *.log
	rm -rf modelsim.ini