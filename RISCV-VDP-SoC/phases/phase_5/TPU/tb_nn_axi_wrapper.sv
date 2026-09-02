`timescale 1ns / 1ps

module tb_nn_axi_wrapper;

    reg clk;
    reg rst_n;

    reg        bus_req;
    reg        bus_write;
    reg [31:0] bus_addr;
    reg [31:0] bus_wdata;
    reg [3:0]  bus_strb;

    wire        bus_ready;
    wire [31:0] bus_rdata;

    wire axis_start;

    wire [63:0] weight0;
    wire [63:0] weight1;
    wire [63:0] weight2;
    wire [63:0] weight3;
    wire [63:0] weight4;

    wire [63:0] input0;
    wire [63:0] input1;

    reg axis_busy;
    reg axis_done;

    reg [63:0] result0;
    reg [63:0] result1;

    integer errors;

    // =========================================================================
    // DUT
    // =========================================================================

    nn_axi_wrapper dut (
        .clk        (clk),
        .rst_n      (rst_n),

        .bus_req    (bus_req),
        .bus_write  (bus_write),
        .bus_addr   (bus_addr),
        .bus_wdata   (bus_wdata),
        .bus_strb    (bus_strb),

        .bus_ready  (bus_ready),
        .bus_rdata  (bus_rdata),

        .axis_start (axis_start),

        .weight0    (weight0),
        .weight1    (weight1),
        .weight2    (weight2),
        .weight3    (weight3),
        .weight4    (weight4),

        .input0     (input0),
        .input1     (input1),

        .axis_busy  (axis_busy),
        .axis_done  (axis_done),

        .result0    (result0),
        .result1    (result1)
    );

    // =========================================================================
    // Clock
    // =========================================================================

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =========================================================================
    // Native write task
    // =========================================================================

    task write32;
        input [31:0] addr;
        input [31:0] data;

        begin

            @(posedge clk);

            bus_req   = 1;
            bus_write = 1;
            bus_addr  = addr;
            bus_wdata = data;
            bus_strb  = 4'b1111;

            @(posedge clk);

            bus_req = 0;
            bus_write = 0;
            bus_wdata = 0;
            bus_strb = 0;

        end
    endtask

    // =========================================================================
    // Native read task
    // =========================================================================

    task read32;
        input [31:0] addr;
        input [31:0] expected;

        begin

            @(posedge clk);

            bus_req   = 1;
            bus_write = 0;
            bus_addr  = addr;
            bus_strb  = 0;

            #1;

            if (bus_rdata !== expected) begin

                $display("READ FAIL addr=%h expected=%h got=%h",
                         addr, expected, bus_rdata);

                errors = errors + 1;

            end
            else begin

                $display("READ PASS addr=%h data=%h",
                         addr, bus_rdata);

            end

            @(posedge clk);

            bus_req = 0;

        end
    endtask

    // =========================================================================
    // Test
    // =========================================================================

    initial begin

        errors = 0;

        bus_req   = 0;
        bus_write = 0;
        bus_addr  = 0;
        bus_wdata = 0;
        bus_strb  = 0;

        axis_busy = 0;
        axis_done = 0;

        result0 = 64'h1234_5678_9ABC_DEF0;
        result1 = 64'hFEDC_BA98_7654_3210;

        rst_n = 0;

        repeat (3) @(posedge clk);

        rst_n = 1;

        // -------------------------------------------------------------
        // Write weight0
        // -------------------------------------------------------------

        write32(32'h10, 32'h5566_7788);
        write32(32'h14, 32'h1122_3344);

        if (weight0 !== 64'h1122_3344_5566_7788)
            errors = errors + 1;

        // -------------------------------------------------------------
        // Write remaining operands
        // -------------------------------------------------------------

        write32(32'h18, 32'h0102_0304);
        write32(32'h1C, 32'h0506_0708);

        write32(32'h20, 32'h1112_1314);
        write32(32'h24, 32'h1516_1718);

        write32(32'h28, 32'h2122_2324);
        write32(32'h2C, 32'h2526_2728);

        write32(32'h30, 32'h3132_3334);
        write32(32'h34, 32'h3536_3738);

        write32(32'h38, 32'h4142_4344);
        write32(32'h3C, 32'h4546_4748);

        write32(32'h40, 32'h5152_5354);
        write32(32'h44, 32'h5556_5758);

        // -------------------------------------------------------------
        // Readback
        // -------------------------------------------------------------

        read32(32'h10, 32'h5566_7788);
        read32(32'h14, 32'h1122_3344);

        read32(32'h38, 32'h4142_4344);
        read32(32'h3C, 32'h4546_4748);

        // -------------------------------------------------------------
        // START while idle
        // -------------------------------------------------------------

        write32(32'h00, 32'h0000_0001);

        @(posedge clk);

        if (!axis_start) begin
            $display("FAIL: START pulse was not generated");
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // START while busy must be rejected.
        // -------------------------------------------------------------

        axis_busy = 1;

        write32(32'h00, 32'h0000_0001);

        @(posedge clk);

        if (axis_start) begin
            $display("FAIL: START accepted while BUSY");
            errors = errors + 1;
        end

        axis_busy = 0;

        // -------------------------------------------------------------
        // Result reads
        // -------------------------------------------------------------

        read32(32'h50, 32'h9ABC_DEF0);
        read32(32'h54, 32'h1234_5678);

        read32(32'h58, 32'h7654_3210);
        read32(32'h5C, 32'hFEDC_BA98);

        if (errors == 0)
            $display("TB_NN_AXI_WRAPPER: ALL TESTS PASSED");
        else
            $display("TB_NN_AXI_WRAPPER: %0d ERRORS", errors);

        $finish;

    end

endmodule