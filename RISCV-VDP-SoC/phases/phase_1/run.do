vlib work
vmap work work

vlog -f filelist.filelist
vsim tb_cpu_ram_subsystem

add wave *

run -all
quit-f