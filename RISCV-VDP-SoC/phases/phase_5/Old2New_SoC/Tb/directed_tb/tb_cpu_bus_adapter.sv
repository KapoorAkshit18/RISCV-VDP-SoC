`ifndef TB_CPU_BUS_ADAPTER_V
`define TB_CPU_BUS_ADAPTER_V

`timescale 1ns/1ps

module tb_cpu_bus_adapter;

    reg        mem_valid;
    reg        mem_instr;
    reg [31:0] mem_addr;
    reg [31:0] mem_wdata;
    reg [3:0]  mem_wstrb;

    wire        mem_ready;
    wire [31:0] mem_rdata;

    wire        m_valid;
    wire        m_write;
    wire [31:0] m_addr;
    wire [31:0] m_wdata;
    wire [3:0]  m_strb;

    reg         m_ready;
    reg  [31:0] m_rdata;

    integer errors;

    cpu_bus_adapter dut (
        .mem_valid  (mem_valid),
        .mem_instr  (mem_instr),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),

        .mem_ready  (mem_ready),
        .mem_rdata  (mem_rdata),

        .m_valid    (m_valid),
        .m_write    (m_write),
        .m_addr     (m_addr),
        .m_wdata    (m_wdata),
        .m_strb     (m_strb),

        .m_ready    (m_ready),
        .m_rdata    (m_rdata)
    );

    task check;
        input condition;
        input [255:0] message;
        begin
            if (condition)
                $display("[PASS] %s", message);
            else begin
                $display("[FAIL] %s", message);
                errors = errors + 1;
            end
        end
    endtask

    initial begin

        errors = 0;

        mem_valid = 0;
        mem_instr = 0;
        mem_addr  = 0;
        mem_wdata = 0;
        mem_wstrb = 0;

        m_ready = 0;
        m_rdata = 0;

        #10;

        // --------------------------------------------
        // TEST 1: Instruction fetch / READ
        // --------------------------------------------

        $display("[TEST] Instruction fetch");

        mem_valid = 1;
        mem_instr = 1;
        mem_addr  = 32'h0000_0010;
        mem_wstrb = 4'b0000;

        #1;

        check(
            m_valid &&
            !m_write &&
            m_addr == 32'h0000_0010 &&
            m_strb == 4'b0000,
            "Instruction fetch mapped as read"
        );

        // --------------------------------------------
        // TEST 2: Load / READ
        // --------------------------------------------

        $display("[TEST] Load transaction");

        mem_instr = 0;
        mem_addr  = 32'h0000_0020;
        mem_wstrb = 4'b0000;

        #1;

        check(
            m_valid &&
            !m_write &&
            m_addr == 32'h0000_0020,
            "Load mapped as read"
        );

        // --------------------------------------------
        // TEST 3: Full-word WRITE
        // --------------------------------------------

        $display("[TEST] Full-word store");

        mem_addr  = 32'h0000_0030;
        mem_wdata = 32'h1234_ABCD;
        mem_wstrb = 4'b1111;

        #1;

        check(
            m_valid &&
            m_write &&
            m_addr == 32'h0000_0030 &&
            m_wdata == 32'h1234_ABCD &&
            m_strb == 4'b1111,
            "Full-word store mapped correctly"
        );

        // --------------------------------------------
        // TEST 4: Byte WRITE
        // --------------------------------------------

        $display("[TEST] Byte store");

        mem_addr  = 32'h0000_0040;
        mem_wdata = 32'h0000_0055;
        mem_wstrb = 4'b0001;

        #1;

        check(
            m_valid &&
            m_write &&
            m_strb == 4'b0001,
            "Byte store detected as write"
        );

        // --------------------------------------------
        // TEST 5: Half-word WRITE
        // --------------------------------------------

        $display("[TEST] Half-word store");

        mem_addr  = 32'h0000_0050;
        mem_wdata = 32'h0000_AAAA;
        mem_wstrb = 4'b0011;

        #1;

        check(
            m_valid &&
            m_write &&
            m_strb == 4'b0011,
            "Half-word store detected as write"
        );

        // --------------------------------------------
        // TEST 6: READY propagation
        // --------------------------------------------

        $display("[TEST] Ready propagation");

        m_ready = 1;

        #1;

        check(
            mem_ready == 1,
            "m_ready propagated to mem_ready"
        );

        m_ready = 0;

        #1;

        check(
            mem_ready == 0,
            "Ready deassertion propagated"
        );

        // --------------------------------------------
        // TEST 7: RDATA propagation
        // --------------------------------------------

        $display("[TEST] Read-data propagation");

        m_rdata = 32'hDEAD_BEEF;

        #1;

        check(
            mem_rdata == 32'hDEAD_BEEF,
            "m_rdata propagated to mem_rdata"
        );

        // --------------------------------------------
        // TEST 8: VALID propagation
        // --------------------------------------------

        $display("[TEST] Valid propagation");

        mem_valid = 0;

        #1;

        check(
            m_valid == 0,
            "mem_valid deassertion propagated"
        );

        // --------------------------------------------

        if (errors == 0) begin
            $display("----------------------------------------");
            $display("CPU BUS ADAPTER TEST PASSED");
            $display("----------------------------------------");
        end
        else begin
            $display("----------------------------------------");
            $display("%0d TEST(S) FAILED", errors);
            $display("----------------------------------------");
        end

        $finish;
    end

endmodule

`endif