`timescale 1ns / 1ps
`ifndef TB_NN_AXI_WRAPPER_SV
`define TB_NN_AXI_WRAPPER_SV

// ============================================================================
// Testbench : tb_nn_axi_wrapper
//
// Purpose:
//   Verify the memory-mapped interface of nn_axi_wrapper.
//
// Verification covers:
//   1. Reset behavior
//   2. 64-bit weight register writes
//   3. 64-bit input register writes
//   4. Register readback
//   5. START command while accelerator is IDLE
//   6. START rejection while accelerator is BUSY
//   7. Result register readback
//
// Important architecture note:
//   This testbench verifies the MMIO/register-bank wrapper only.
//
//   CPU/native bus
//          |
//          v
//   nn_axi_wrapper
//          |
//          +---- axis_start
//          +---- weight0..weight4
//          +---- input0,input1
//          +---- result0,result1
//          |
//          v
//   AXIS/TPU logic
//
// There is NO AXI4-Stream transaction generated directly by this TB.
// That is tested separately in tb_nn_axis_master.
//
// ============================================================================

module tb_nn_axi_wrapper;

    // =========================================================================
    // Clock and reset
    // =========================================================================

    reg clk;
    reg rst_n;

    // =========================================================================
    // Native memory-mapped bus
    // =========================================================================

    reg        bus_req;
    reg        bus_write;
    reg [31:0] bus_addr;
    reg [31:0] bus_wdata;
    reg [3:0]  bus_strb;

    wire       bus_ready;
    wire [31:0] bus_rdata;

    // =========================================================================
    // Accelerator command interface
    // =========================================================================

    wire axis_start;

    // =========================================================================
    // Operand outputs
    // =========================================================================

    wire [63:0] weight0;
    wire [63:0] weight1;
    wire [63:0] weight2;
    wire [63:0] weight3;
    wire [63:0] weight4;

    wire [63:0] input0;
    wire [63:0] input1;

    // =========================================================================
    // Accelerator status inputs
    // =========================================================================

    reg axis_busy;
    reg axis_done;

    // =========================================================================
    // Accelerator result inputs
    // =========================================================================

    reg [63:0] result0;
    reg [63:0] result1;

    // =========================================================================
    // Verification
    // =========================================================================

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
        .bus_wdata  (bus_wdata),
        .bus_strb   (bus_strb),

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
    // Clock generation
    //
    // 100 MHz clock:
    //     Period    = 10 ns
    //     Half      = 5 ns
    // =========================================================================

    initial begin
        clk = 1'b0;

        forever begin
            #5 clk = ~clk;
        end
    end

    // =========================================================================
    // Native 32-bit WRITE transaction
    //
    // The DUT samples the request at the second rising edge.
    //
    // Timeline:
    //
    //       posedge              posedge
    //          |                    |
    //          |<--- transaction -->|
    //          |
    //       drive bus           DUT samples
    //
    // =========================================================================

    task write32;

        input [31:0] addr;
        input [31:0] data;

        begin

            // ---------------------------------------------------------------
            // Wait for a clean clock edge before driving transaction.
            // ---------------------------------------------------------------

            @(posedge clk);

            bus_req   = 1'b1;
            bus_write = 1'b1;
            bus_addr  = addr;
            bus_wdata = data;
            bus_strb  = 4'b1111;

            // ---------------------------------------------------------------
            // DUT samples bus transaction here.
            // ---------------------------------------------------------------

            @(posedge clk);
// ---------------------------------------------------------------
#1; // delay to allow nonblocking assignments inside the DUT to update.


            // ---------------------------------------------------------------
            // Remove request after sampling edge.
            // ---------------------------------------------------------------

            bus_req   = 1'b0;
            bus_write = 1'b0;
            bus_addr  = 32'h0000_0000;
            bus_wdata = 32'h0000_0000;
            bus_strb  = 4'b0000;

        end

    endtask

    // =========================================================================
    // Native 32-bit READ transaction
    //
    // bus_rdata is combinationally decoded from bus_addr in the DUT.
    //
    // Therefore the testbench:
    //   1. Drives the address.
    //   2. Waits a small delta/time.
    //   3. Checks bus_rdata.
    //   4. Removes the request.
    // =========================================================================

    task read32;

        input [31:0] addr;
        input [31:0] expected;

        begin

            // ---------------------------------------------------------------
            // Begin read transaction.
            // ---------------------------------------------------------------

            @(posedge clk);

            bus_req   = 1'b1;
            bus_write = 1'b0;
            bus_addr  = addr;
            bus_wdata = 32'h0000_0000;
            bus_strb  = 4'b0000;

            // ---------------------------------------------------------------
            // Allow combinational read-data logic to settle.
            // ---------------------------------------------------------------

            #1;

            // ---------------------------------------------------------------
            // Verify returned data.
            // ---------------------------------------------------------------

            if (bus_rdata !== expected) begin

                $display(
                    "READ FAIL : addr=%h expected=%h got=%h",
                    addr,
                    expected,
                    bus_rdata
                );

                errors = errors + 1;

            end
            else begin

                $display(
                    "READ PASS : addr=%h data=%h",
                    addr,
                    bus_rdata
                );

            end

            // ---------------------------------------------------------------
            // End read transaction.
            // ---------------------------------------------------------------

            @(posedge clk);

            bus_req   = 1'b0;
            bus_write = 1'b0;
            bus_addr  = 32'h0000_0000;
            bus_wdata = 32'h0000_0000;
            bus_strb  = 4'b0000;

        end

    endtask

    // =========================================================================
    // START EXPECTATION TASK
    //
    // This task performs:
    //
    //       CONTROL register write
    //       CONTROL[0] = 1
    //
    // and checks whether axis_start becomes the expected value.
    //
    // expected_start = 1
    //     Accelerator is IDLE.
    //     START should be accepted.
    //
    // expected_start = 0
    //     Accelerator is BUSY.
    //     START should be rejected.
    //
    // IMPORTANT:
    //   The check occurs immediately after the clock edge at which the DUT
    //   samples the bus request.
    //
    //   The #1 delay allows nonblocking assignments inside the DUT to update.
    // =========================================================================

    task start_expect;

        input expected_start;

        begin

            // ---------------------------------------------------------------
            // Drive CONTROL write.
            // ---------------------------------------------------------------

            @(posedge clk);

            bus_req   = 1'b1;
            bus_write = 1'b1;
            bus_addr  = 32'h0000_0000;
            bus_wdata = 32'h0000_0001;
            bus_strb  = 4'b1111;

            // ---------------------------------------------------------------
            // DUT samples CONTROL write at this edge.
            // ---------------------------------------------------------------

            @(posedge clk);

            // ---------------------------------------------------------------
            // Wait for NBA update of axis_start.
            // ---------------------------------------------------------------

            #1;

            // ---------------------------------------------------------------
            // Check generated START pulse.
            // ---------------------------------------------------------------

            if (axis_start !== expected_start) begin

                $display(
                    "START FAIL : busy=%b expected_start=%b actual_start=%b",
                    axis_busy,
                    expected_start,
                    axis_start
                );

                errors = errors + 1;

            end
            else begin

                $display(
                    "START PASS : busy=%b expected_start=%b actual_start=%b",
                    axis_busy,
                    expected_start,
                    axis_start
                );

            end

            // ---------------------------------------------------------------
            // End bus transaction.
            // ---------------------------------------------------------------

            bus_req   = 1'b0;
            bus_write = 1'b0;
            bus_addr  = 32'h0000_0000;
            bus_wdata = 32'h0000_0000;
            bus_strb  = 4'b0000;

        end

    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================

    initial begin

        // =====================================================================
        // Initial state
        // =====================================================================

        errors = 0;

        bus_req   = 1'b0;
        bus_write = 1'b0;
        bus_addr  = 32'h0000_0000;
        bus_wdata = 32'h0000_0000;
        bus_strb  = 4'b0000;

        axis_busy = 1'b0;
        axis_done = 1'b0;

        result0 = 64'h1234_5678_9ABC_DEF0;
        result1 = 64'hFEDC_BA98_7654_3210;

        // =====================================================================
        // RESET
        // =====================================================================

        rst_n = 1'b0;

        $display("--------------------------------------------------");
        $display("Applying reset...");
        $display("--------------------------------------------------");

        repeat (3) begin
            @(posedge clk);
        end

        rst_n = 1'b1;

        $display("Reset released.");

        // =====================================================================
        // WEIGHT0
        //
        // weight0 = 64'h1122_3344_5566_7788
        //
        // Low word  -> address 0x10
        // High word -> address 0x14
        // =====================================================================

        $display("--------------------------------------------------");
        $display("Testing WEIGHT0 register");
        $display("--------------------------------------------------");

        write32(
            32'h0000_0010,
            32'h5566_7788
        );

        write32(
            32'h0000_0014,
            32'h1122_3344
        );

        if (weight0 !== 64'h1122_3344_5566_7788) begin

            $display(
                "WRITE FAIL : weight0 expected=%h got=%h",
                64'h1122_3344_5566_7788,
                weight0
            );

            errors = errors + 1;

        end
        else begin

            $display(
                "WRITE PASS : weight0=%h",
                weight0
            );

        end

        // =====================================================================
        // WEIGHT1
        // =====================================================================

        write32(32'h0000_0018, 32'h0102_0304);
        write32(32'h0000_001C, 32'h0506_0708);

        if (weight1 !== 64'h0506_0708_0102_0304) begin
            $display("WRITE FAIL : weight1=%h", weight1);
            errors = errors + 1;
        end
        else begin
            $display("WRITE PASS : weight1=%h", weight1);
        end

        // =====================================================================
        // WEIGHT2
        // =====================================================================

        write32(32'h0000_0020, 32'h1112_1314);
        write32(32'h0000_0024, 32'h1516_1718);

        if (weight2 !== 64'h1516_1718_1112_1314) begin
            $display("WRITE FAIL : weight2=%h", weight2);
            errors = errors + 1;
        end
        else begin
            $display("WRITE PASS : weight2=%h", weight2);
        end

        // =====================================================================
        // WEIGHT3
        // =====================================================================

        write32(32'h0000_0028, 32'h2122_2324);
        write32(32'h0000_002C, 32'h2526_2728);

        if (weight3 !== 64'h2526_2728_2122_2324) begin
            $display("WRITE FAIL : weight3=%h", weight3);
            errors = errors + 1;
        end
        else begin
            $display("WRITE PASS : weight3=%h", weight3);
        end

        // =====================================================================
        // WEIGHT4
        // =====================================================================

        write32(32'h0000_0030, 32'h3132_3334);
        write32(32'h0000_0034, 32'h3536_3738);

        if (weight4 !== 64'h3536_3738_3132_3334) begin
            $display("WRITE FAIL : weight4=%h", weight4);
            errors = errors + 1;
        end
        else begin
            $display("WRITE PASS : weight4=%h", weight4);
        end

        // =====================================================================
        // INPUT0
        // =====================================================================

        write32(32'h0000_0038, 32'h4142_4344);
        write32(32'h0000_003C, 32'h4546_4748);

        if (input0 !== 64'h4546_4748_4142_4344) begin
            $display("WRITE FAIL : input0=%h", input0);
            errors = errors + 1;
        end
        else begin
            $display("WRITE PASS : input0=%h", input0);
        end

        // =====================================================================
        // INPUT1
        // =====================================================================

        write32(32'h0000_0040, 32'h5152_5354);
        write32(32'h0000_0044, 32'h5556_5758);

        if (input1 !== 64'h5556_5758_5152_5354) begin
            $display("WRITE FAIL : input1=%h", input1);
            errors = errors + 1;
        end
        else begin
            $display("WRITE PASS : input1=%h", input1);
        end

        // =====================================================================
        // READBACK TESTS
        // =====================================================================

        $display("--------------------------------------------------");
        $display("Testing register readback");
        $display("--------------------------------------------------");

        read32(
            32'h0000_0010,
            32'h5566_7788
        );

        read32(
            32'h0000_0014,
            32'h1122_3344
        );

        read32(
            32'h0000_0018,
            32'h0102_0304
        );

        read32(
            32'h0000_001C,
            32'h0506_0708
        );

        read32(
            32'h0000_0038,
            32'h4142_4344
        );

        read32(
            32'h0000_003C,
            32'h4546_4748
        );

        read32(
            32'h0000_0040,
            32'h5152_5354
        );

        read32(
            32'h0000_0044,
            32'h5556_5758
        );

        // =====================================================================
        // START TEST - ACCELERATOR IDLE
        //
        // axis_busy = 0
        //
        // CONTROL[0] = 1
        //
        // Expected:
        //     axis_start = 1
        // =====================================================================

        $display("--------------------------------------------------");
        $display("Testing START while accelerator is IDLE");
        $display("--------------------------------------------------");

        axis_busy = 1'b0;

        start_expect(1'b1);

        // =====================================================================
        // START TEST - ACCELERATOR BUSY
        //
        // axis_busy = 1
        //
        // CONTROL[0] = 1
        //
        // Expected:
        //     axis_start = 0
        // =====================================================================

        $display("--------------------------------------------------");
        $display("Testing START while accelerator is BUSY");
        $display("--------------------------------------------------");

        axis_busy = 1'b1;

        start_expect(1'b0);

        axis_busy = 1'b0;

        // =====================================================================
        // RESULT REGISTER READBACK
        //
        // result0 = 64'h1234_5678_9ABC_DEF0
        // result1 = 64'hFEDC_BA98_7654_3210
        // =====================================================================

        $display("--------------------------------------------------");
        $display("Testing RESULT register readback");
        $display("--------------------------------------------------");

        read32(
            32'h0000_0050,
            32'h9ABC_DEF0
        );

        read32(
            32'h0000_0054,
            32'h1234_5678
        );

        read32(
            32'h0000_0058,
            32'h7654_3210
        );

        read32(
            32'h0000_005C,
            32'hFEDC_BA98
        );

        // =====================================================================
        // FINAL RESULT
        // =====================================================================

        $display("--------------------------------------------------");

        if (errors == 0) begin

            $display(
                "TB_NN_AXI_WRAPPER: ALL TESTS PASSED"
            );

        end
        else begin

            $display(
                "TB_NN_AXI_WRAPPER: %0d ERRORS",
                errors
            );

        end

        $display("--------------------------------------------------");

        $finish;

    end

endmodule
`endif