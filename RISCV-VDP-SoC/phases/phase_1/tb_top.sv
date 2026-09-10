`timescale 1ns/1ps

module tb_top;

    // ============================================================
    // Parameters
    // ============================================================
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter RAM_DEPTH  = 16384;

    // ============================================================
    // Testbench signals
    // ============================================================
    reg clk;
    reg resetn;

    wire cpu_trap;

    integer i;

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
    // Load firmware
    // ============================================================
    initial begin
    $readmemh("firmware_test2/firmware_new.hex", dut.u_ram.mem);
        end
    
    // ============================================================
    // Clock
    // 100 MHz = 10 ns period
    // ============================================================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // Reset
    // ============================================================
    initial begin

        resetn = 1'b0;

        $display("[%0t ns] Reset asserted", $time);

        // Hold reset for 100 ns
        #100;

        resetn = 1'b1;

        $display("[%0t ns] Reset released", $time);
        $display("");
        $display("Starting firmware execution...");
        $display("");

    end
// cpu --> adapter
always @(posedge clk) begin
    if (dut.mem_valid && |dut.mem_wstrb) begin
        $display(
            "[%0t] CPU BUS WRITE: addr=%08h data=%08h strb=%h",
            $time,
            dut.mem_addr,
            dut.mem_wdata,
            dut.mem_wstrb
        );
    end
end

// adapter --> interconnect 
always @(posedge clk) begin
    if (dut.m_valid && dut.m_write) begin
        $display(
            "[%0t] ADAPTER WRITE: addr=%08h data=%08h strb=%h ready=%b",
            $time,
            dut.m_addr,
            dut.m_wdata,
            dut.m_strb,
            dut.m_ready
        );
    end
end

// interconnect --> ram
always @(posedge clk) begin
    if (dut.ram_valid && dut.ram_write) begin
        $display(
            "[%0t] RAM INTERFACE WRITE: addr=%08h index=%0d data=%08h strb=%h ready=%b",
            $time,
            dut.ram_addr,
            dut.ram_addr >> 2,
            dut.ram_wdata,
            dut.ram_strb,
            dut.ram_ready
        );
    end
end

    // ============================================================
    // CPU BUS MONITOR
    //
    // IMPORTANT:
    // These signals must exist at cpu_soc_ram_top level.
    // If they do not, we will use the actual internal hierarchy.
    // ============================================================
    always @(posedge clk) begin

        if (dut.m_valid && dut.m_ready) begin

            if (dut.m_write) begin

                $display(
                    "[%0t ns] CPU WRITE: addr=%08h data=%08h strb=%h",
                    $time,
                    dut.m_addr,
                    dut.m_wdata,
                    dut.m_strb
                );

            end
            else begin

                $display(
                    "[%0t ns] CPU READ : addr=%08h data=%08h",
                    $time,
                    dut.m_addr,
                    dut.m_rdata
                );

            end

        end

    end

// ============================================================
// CPU internal signals monitor
    always @(posedge clk) begin
    if (dut.u_cpu.prv.reg_pc >= 32'h0000004c &&
        dut.u_cpu.prv.reg_pc <= 32'h00000088) begin

        $display("%0t PC=%h  a5(x15)=%h  a7(x17)=%h  a2(x12)=%h  a0(x10)=%h  write=%b wrdata=%h",
            $time,
            dut.u_cpu.prv.reg_pc,
            dut.u_cpu.prv.cpuregs[15],
            dut.u_cpu.prv.cpuregs[17],
            dut.u_cpu.prv.cpuregs[12],
            dut.u_cpu.prv.cpuregs[10],
            dut.u_cpu.prv.cpuregs_write,
            dut.u_cpu.prv.cpuregs_wrdata
        );
    end
end
// ============================================================
// monitor for the specific instruction near addi and is add
always @(posedge clk) begin
    if (dut.u_cpu.prv.reg_pc == 32'h00000054) begin
        $display("%0t PC=%h x30(t5)=%h x10(a0)=%h x28(t3)=%h",
            $time,
            dut.u_cpu.prv.reg_pc,
            dut.u_cpu.prv.cpuregs[30],
            dut.u_cpu.prv.cpuregs[10],
            dut.u_cpu.prv.cpuregs[28]
        );
    end
end
// monitor for the specific instruction near addi and is add debug xxxx 
always @(posedge clk) begin
    if (dut.u_cpu.prv.reg_pc >= 32'h38 &&
        dut.u_cpu.prv.reg_pc <= 32'h54) begin
        $display("%0t PC=%h x12(a2)=%h x30(t5)=%h rd=%0d wr=%b wrdata=%h",
            $time,
            dut.u_cpu.prv.reg_pc,
            dut.u_cpu.prv.cpuregs[12],
            dut.u_cpu.prv.cpuregs[30],
            dut.u_cpu.prv.latched_rd,
            dut.u_cpu.prv.cpuregs_write,
            dut.u_cpu.prv.cpuregs_wrdata
        );
    end
end


// monitor for the condition followed by the cpu 
always @(posedge clk) begin
    if (dut.u_cpu.prv.cpuregs_write && dut.u_cpu.prv.latched_rd) begin
        $display("%0t REG WRITE: rd=x%0d data=%h PC=%h",
            $time,
            dut.u_cpu.prv.latched_rd,
            dut.u_cpu.prv.cpuregs_wrdata,
            dut.u_cpu.prv.reg_pc
        );
    end
end
// monitor for the specific address
always @(posedge clk) begin
    if (dut.u_cpu.prv.reg_pc == 32'h0000004c) begin
        $display("%0t LW a5: x15 BEFORE=%h  wr=%b rd=%0d wrdata=%h mem_rdata=%h",
            $time,
            dut.u_cpu.prv.cpuregs[15],
            dut.u_cpu.prv.cpuregs_write,
            dut.u_cpu.prv.latched_rd,
            dut.u_cpu.prv.cpuregs_wrdata,
            dut.u_cpu.prv.mem_rdata
        );
    end
end

    // ============================================================
    // Specifically monitor output[] writes
    //
    // output[0]  = 0x1220
    // output[31] = 0x129C
    // ============================================================
    always @(posedge clk) begin

        if (dut.m_valid &&
            dut.m_ready &&
            dut.m_write) begin

            if ((dut.m_addr >= 32'h0000_1220) &&
                (dut.m_addr <= 32'h0000_129C)) begin

                $display(
                    ">>> OUTPUT WRITE: output[%0d] addr=%08h data=%08h strb=%h",
                    (dut.m_addr - 32'h0000_1220) >> 2,
                    dut.m_addr,
                    dut.m_wdata,
                    dut.m_strb
                );

            end

        end

    end

    // ============================================================
    // Trap monitor
    // ============================================================
    always @(posedge clk) begin

        if (cpu_trap) begin
            $display("");
            $display("==============================================");
            $display("CPU TRAP DETECTED");
            $display("time = %0t ns", $time);
            $display("==============================================");
            $display("");
        end

    end

    // ============================================================
    // VCD waveform
    // ============================================================
    initial begin

        $dumpfile("cpu_soc_ram_top.vcd");
        $dumpvars(0, tb_top);

    end

    // ============================================================
    // Final RAM check
    //
    // 100 us = 10,000 CPU cycles at 100 MHz.
    // Our previous full simulation reached 0x22222222 at
    // approximately 33 us, so this gives sufficient time.
    // ============================================================
    initial begin

        #100000;

        $display("");
        $display("==============================================");
        $display("SIMULATION TIMEOUT / FINAL RAM CHECK");
        $display("==============================================");

        $display("");
        $display("OUTPUT ARRAY:");
        $display("");

        for (i = 0; i < 32; i = i + 1) begin

            $display(
                "output[%0d] : mem[%0d] = %08h   expected = %08h",
                i,
                1160 + i,
                dut.u_ram.mem[1160 + i],
                (i + 1) * 273
            );

        end

        $display("");
        $display("==============================================");

        $stop;

    end

endmodule