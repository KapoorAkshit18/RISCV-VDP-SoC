`timescale 1ns/1ps

module tb_top;

    // ============================================================
    // Parameters
    // ============================================================
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter RAM_DEPTH  = 256;

    // ============================================================
    // Testbench signals
    // ============================================================
    reg clk;
    reg resetn;

    wire cpu_trap;

    // ============================================================
    // DUT
    // ============================================================
    cpu_soc_ram_top #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .RAM_DEPTH  (RAM_DEPTH)
    ) dut (
        .clk      (clk),
        .resetn   (resetn),
        .cpu_trap (cpu_trap)
    );
    // ============================================================
    // Loading the Hex file generate from the riscv gnu toolchain
    // ============================================================
    initial begin
    $readmemh("firmware/firmware.hex", dut.u_ram.mem);
        end
    
    // ============================================================
    // Clock generation
    // 100 MHz clock = 10 ns period
    // ============================================================
    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end

    // ============================================================
    // Reset sequence
    // ============================================================
    initial begin
        resetn = 1'b0;

        // Hold reset for 100 ns
        #100;

        resetn = 1'b1;

        $display("[%0t ns] Reset released", $time);
    end

    // ============================================================
    // VCD waveform dump
    // ============================================================
    initial begin
        $dumpfile("cpu_soc_ram_top.vcd");
        $dumpvars(0, tb_top);
    end

    // ============================================================
    // Monitor
    // ============================================================
    initial begin
        $monitor(
            "[%0t ns] clk=%b resetn=%b trap=%b",
            $time,
            clk,
            resetn,
            cpu_trap
        );
    end

    // ============================================================
    // Simulation timeout
    // ============================================================
    initial begin
        #10000;

        $display("[%0t ns] Simulation finished", $time);

        $stop;
    end

endmodule