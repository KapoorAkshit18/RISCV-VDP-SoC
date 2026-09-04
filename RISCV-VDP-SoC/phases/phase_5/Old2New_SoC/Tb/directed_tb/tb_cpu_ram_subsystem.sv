`ifndef TB_CPU_RAM_SUBSYSTEM_V
`define TB_CPU_RAM_SUBSYSTEM_V

// `timescale 1ns/1ps

module tb_cpu_ram_subsystem;

    reg clk;
    reg resetn;

    wire cpu_trap;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------

    cpu_ram_subsystem #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .RAM_DEPTH (256)
    ) dut (
        .clk      (clk),
        .resetn   (resetn),
        .cpu_trap (cpu_trap)
    );

    // ------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------

    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------
    // Waveform
    // ------------------------------------------------------------

    initial begin
        $dumpfile("cpu_ram_subsystem.vcd");
        $dumpvars(0, tb_cpu_ram_subsystem);
    end

    // ------------------------------------------------------------
    // Program initialization
    //
    // RAM contents are initialized through hierarchical access
    // for this integration test.
    // ------------------------------------------------------------

    initial begin

        // Clear RAM
        for (integer i = 0; i < 256; i = i + 1)
            dut.u_ram.mem[i] = 32'h0000_0000;

        // --------------------------------------------------------
        // Program
        // --------------------------------------------------------

        // 0x0000:
        // lui x1, 0x12345
        // x1 = 0x12345000
        dut.u_ram.mem[0] = 32'h123450B7;

        // 0x0004:
        // addi x2, x0, 42
        // x2 = 42
        dut.u_ram.mem[1] = 32'h02A00113;

        // 0x0008:
        // sw x2, 0x100(x0)
        // RAM[0x100] = 42
        dut.u_ram.mem[2] = 32'h10202023;

        // 0x000C:
        // lw x3, 0x100(x0)
        // x3 = 42
        dut.u_ram.mem[3] = 32'h10002183;

        // 0x0010:
        // illegal instruction
        // causes trap
        dut.u_ram.mem[4] = 32'h00000000;

        // --------------------------------------------------------
        // Initial data location
        // --------------------------------------------------------

        dut.u_ram.mem[64] = 32'h00000000;

        // --------------------------------------------------------
        // Reset
        // --------------------------------------------------------

        resetn = 1'b0;

        #50;

        resetn = 1'b1;

        $display("");
        $display("========================================");
        $display("[TEST START] CPU -> RAM INTEGRATION");
        $display("========================================");

    end
//--------------------------------------------debug
//riscv
always @(posedge clk) begin
    if (resetn && dut.mem_valid) begin
        $display(
            "[BUS] valid=%b ready=%b instr=%b addr=%08x wdata=%08x rdata=%08x strb=%b",
            dut.mem_valid,
            dut.mem_ready,
            dut.mem_instr,
            dut.mem_addr,
            dut.mem_wdata,
            dut.mem_rdata,
            dut.mem_wstrb
        );
    end
end
//ram
always @(posedge clk) begin
    if (resetn && dut.ram_valid) begin
        $display(
            "[RAM] valid=%b ready=%b write=%b addr=%08x rdata=%08x",
            dut.ram_valid,
            dut.ram_ready,
            dut.ram_write,
            dut.ram_addr,
            dut.ram_rdata
        );
    end
end

// more ramdebug
always @(posedge clk) begin
    if (resetn) begin
        $display("[DEBUG] ram_valid=%b ram_ready=%b",
                 dut.ram_valid,
                 dut.ram_ready);
    end
end




///////////////////////////

    // ------------------------------------------------------------
    // Monitor CPU transactions
    // ------------------------------------------------------------

    always @(posedge clk) begin

        if (resetn) begin

            if (dut.mem_valid) begin

                if (dut.mem_wstrb == 4'b0000) begin

                    if (dut.mem_instr)
                        $display(
                            "[FETCH] Addr=0x%08x Data=0x%08x",
                            dut.mem_addr,
                            dut.mem_rdata
                        );
                    else
                        $display(
                            "[READ ] Addr=0x%08x Data=0x%08x",
                            dut.mem_addr,
                            dut.mem_rdata
                        );

                end
                else begin

                    $display(
                        "[WRITE] Addr=0x%08x Data=0x%08x STRB=%b",
                        dut.mem_addr,
                        dut.mem_wdata,
                        dut.mem_wstrb
                    );

                end
            end

        end
    end

    // ------------------------------------------------------------
    // Wait for CPU trap
    // ------------------------------------------------------------

    initial begin

        wait(resetn == 1'b1);

        wait(cpu_trap == 1'b1);

        #10;

        $display("");
        $display("[TEST] CPU trap reached");

        // --------------------------------------------------------
        // Check stored value
        // --------------------------------------------------------

        if (dut.u_ram.mem[64] == 32'd42) begin

            $display("[PASS] CPU store reached RAM");
            $display("[PASS] RAM contains expected value = %0d",
                     dut.u_ram.mem[64]);

        end
        else begin

            $display("[FAIL] RAM expected 42, got 0x%08x",
                     dut.u_ram.mem[64]);

        end

        // --------------------------------------------------------
        // Final result
        // --------------------------------------------------------

        if (cpu_trap &&
            dut.u_ram.mem[64] == 32'd42) begin

            $display("");
            $display("========================================");
            $display("CPU -> RAM INTEGRATION TEST PASSED");
            $display("========================================");

        end
        else begin

            $display("");
            $display("========================================");
            $display("CPU -> RAM INTEGRATION TEST FAILED");
            $display("========================================");

        end

        $finish;
    end

endmodule

`endif