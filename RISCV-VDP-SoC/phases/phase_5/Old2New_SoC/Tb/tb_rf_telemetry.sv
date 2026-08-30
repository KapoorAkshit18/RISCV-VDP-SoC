`timescale 1ns/1ps

// =============================================================================
// tb_rf_telemetry_native.v
//
// Self-checking testbench for rf_telemetry_native_slave.
//
// PicoRV32 native memory interface:
//
//   mem_valid
//   mem_ready
//   mem_addr
//   mem_wdata
//   mem_wstrb
//   mem_rdata
//
// Run:
//   iverilog -o sim_rf tb_rf_telemetry_native.v ../rtl/rf_telemetry_native_slave.v
//   vvp sim_rf
// =============================================================================

module tb_rf_telemetry_native;

    reg clk = 0;
    reg resetn;

    // ============================================================
    // PicoRV32 native bus
    // ============================================================

    reg         mem_valid;
    reg         mem_instr;
    wire        mem_ready;

    reg  [11:0] mem_addr;
    reg  [31:0] mem_wdata;
    reg  [3:0]  mem_wstrb;

    wire [31:0] mem_rdata;

    // ============================================================
    // RF inputs
    // ============================================================

    reg  [7:0] rssi_dbm;
    reg        link_up;
    reg        link_error;
    reg        carrier_detect;

    // ============================================================
    // RF output
    // ============================================================

    wire rf_enable;

    integer errors = 0;

    // ============================================================
    // DUT
    // ============================================================

    rf_telemetry_native_slave #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(32)
    ) dut (
        .clk                (clk),
        .resetn             (resetn),

        .mem_valid          (mem_valid),
        .mem_instr          (mem_instr),
        .mem_ready          (mem_ready),
        .mem_addr           (mem_addr),
        .mem_wdata          (mem_wdata),
        .mem_wstrb          (mem_wstrb),
        .mem_rdata          (mem_rdata),

        .rssi_dbm_i         (rssi_dbm),
        .link_up_i          (link_up),
        .link_error_i       (link_error),
        .carrier_detect_i   (carrier_detect),

        .rf_enable_o        (rf_enable)
    );

    // ============================================================
    // 100 MHz clock
    // ============================================================

    always #5 clk = ~clk;

    // ============================================================
    // Native write task
    //
    // Holds mem_valid until mem_ready.
    // ============================================================

    task native_write;

        input [11:0] addr;
        input [31:0] data;
        input [3:0]  strb;

        begin

            @(posedge clk);

            mem_addr  <= addr;
            mem_wdata <= data;
            mem_wstrb <= strb;
            mem_instr <= 1'b0;
            mem_valid <= 1'b1;

            // Wait for slave completion.
            @(posedge clk);

            while (!mem_ready)
                @(posedge clk);

            mem_valid <= 1'b0;
            mem_wstrb <= 4'b0000;

            @(posedge clk);

        end

    endtask

    // ============================================================
    // Native read task
    //
    // mem_wstrb = 0000 represents a read.
    // ============================================================

    task native_read;

        input  [11:0] addr;
        output [31:0] data;

        begin

            @(posedge clk);

            mem_addr  <= addr;
            mem_wdata <= 32'h0000_0000;
            mem_wstrb <= 4'b0000;
            mem_instr <= 1'b0;
            mem_valid <= 1'b1;

            // Wait for completion.
            @(posedge clk);

            while (!mem_ready)
                @(posedge clk);

            data = mem_rdata;

            mem_valid <= 1'b0;

            @(posedge clk);

        end

    endtask

    // ============================================================
    // Test variables
    // ============================================================

    reg [31:0] rd_data;

    // ============================================================
    // Main test
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // Initial values
        // --------------------------------------------------------

        resetn = 1'b0;

        mem_valid = 1'b0;
        mem_instr = 1'b0;
        mem_addr  = 12'h000;
        mem_wdata = 32'h0000_0000;
        mem_wstrb = 4'b0000;

        // -62 dBm = 8'hC2 in two's complement
        rssi_dbm       = 8'hC2;

        link_up        = 1'b1;
        link_error     = 1'b0;
        carrier_detect = 1'b1;

        // --------------------------------------------------------
        // Reset
        // --------------------------------------------------------

        repeat (4)
            @(posedge clk);

        resetn = 1'b1;

        // Allow the two-FF synchronizers to settle.
        repeat (4)
            @(posedge clk);

        // ========================================================
        // TEST 1
        // Native bus must not respond combinationally.
        // ========================================================

        @(posedge clk);
        #1;
        mem_addr  <= 12'h00C;
        mem_wdata <= 32'h0000_0000;
        mem_wstrb <= 4'b0000;
        mem_valid <= 1'b1;

        if (mem_ready === 1'b0)
            $display(
                "PASS: mem_ready is low when mem_valid is first asserted"
            );
        else begin

            $display(
                "FAIL: mem_ready asserted too early"
            );

            errors = errors + 1;

        end

        // --------------------------------------------------------
        // Next cycle should complete transaction.
        // --------------------------------------------------------

        @(posedge clk);
        #1;
        if (mem_ready === 1'b1)
            $display(
                "PASS: mem_ready asserted one cycle after mem_valid"
            );
        else begin

            $display(
                "FAIL: mem_ready = %b, expected 1",
                mem_ready
            );

            errors = errors + 1;

        end

        mem_valid <= 1'b0;

        @(posedge clk);
        #1;
        // ========================================================
        // TEST 2
        // RF RSSI
        // ========================================================

        native_read(12'h000, rd_data);

        if ($signed(rd_data[7:0]) === -8'sd62)
            $display(
                "PASS: RF_RSSI = %0d dBm",
                $signed(rd_data[7:0])
            );
        else begin

            $display(
                "FAIL: RF_RSSI = %0d (expected -62)",
                $signed(rd_data[7:0])
            );

            errors = errors + 1;

        end

        // ========================================================
        // TEST 3
        // RF LINK STATUS
        //
        // bit0 = link_up        = 1
        // bit1 = link_error     = 0
        // bit2 = carrier_detect = 1
        //
        // Therefore:
        //       101b = 0x00000005
        // ========================================================

        native_read(12'h004, rd_data);

        if (rd_data === 32'h0000_0005)
            $display(
                "PASS: RF_LINK_STAT = %h (link_up=1, error=0, carrier=1)",
                rd_data
            );
        else begin

            $display(
                "FAIL: RF_LINK_STAT = %h (expected 00000005)",
                rd_data
            );

            errors = errors + 1;

        end

        // ========================================================
        // TEST 4
        // RF ID
        // ========================================================

        native_read(12'h00C, rd_data);

        if (rd_data === 32'h5246_5430)
            $display(
                "PASS: RF_ID = %h (\"RFT0\")",
                rd_data
            );
        else begin

            $display(
                "FAIL: RF_ID = %h (expected 52465430)",
                rd_data
            );

            errors = errors + 1;

        end

        // ========================================================
        // TEST 5
        // RF_CONTROL write
        // ========================================================

        native_write(
            12'h008,
            32'h0000_0001,
            4'b1111
        );

        if (rf_enable === 1'b1)
            $display(
                "PASS: rf_enable_o asserted after RF_CONTROL write"
            );
        else begin

            $display(
                "FAIL: rf_enable_o = %b (expected 1)",
                rf_enable
            );

            errors = errors + 1;

        end

        // ========================================================
        // TEST 6
        // RF_CONTROL readback
        // ========================================================

        native_read(12'h008, rd_data);

        if (rd_data === 32'h0000_0001)
            $display(
                "PASS: RF_CONTROL readback = %h",
                rd_data
            );
        else begin

            $display(
                "FAIL: RF_CONTROL readback = %h (expected 00000001)",
                rd_data
            );

            errors = errors + 1;

        end

        // ========================================================
        // TEST 7
        // Disable RF
        // ========================================================

        native_write(
            12'h008,
            32'h0000_0000,
            4'b1111
        );

        if (rf_enable === 1'b0)
            $display(
                "PASS: rf_enable_o deasserted after RF_CONTROL clear"
            );
        else begin

            $display(
                "FAIL: rf_enable_o = %b (expected 0)",
                rf_enable
            );

            errors = errors + 1;

        end

        // ========================================================
        // TEST 8
        // Unmapped read
        //
        // Native bus has no SLVERR response.
        // Expected:
        //
        //     mem_rdata = 0
        //     mem_ready = 1
        // ========================================================

        native_read(12'h0A0, rd_data);

        if (rd_data === 32'h0000_0000)
            $display(
                "PASS: unmapped offset 0x0A0 returns 0"
            );
        else begin

            $display(
                "FAIL: unmapped offset returned %h (expected 0)",
                rd_data
            );

            errors = errors + 1;

        end

        // ========================================================
        // TEST 9
        // Reset behavior
        // ========================================================

        resetn = 1'b0;

        @(posedge clk);
        #1;
        resetn = 1'b1;

        repeat (3)
            @(posedge clk);

        native_read(12'h008, rd_data);

        if (rd_data === 32'h0000_0000 && rf_enable === 1'b0)
            $display(
                "PASS: RF_CONTROL and rf_enable_o reset to 0"
            );
        else begin

            $display(
                "FAIL: reset state CONTROL=%h rf_enable=%b",
                rd_data,
                rf_enable
            );

            errors = errors + 1;

        end

        // ========================================================
        // FINAL RESULT
        // ========================================================

        if (errors == 0)
            $display(
                "==== TB_RF_TELEMETRY_NATIVE: ALL TESTS PASSED ===="
            );
        else
            $display(
                "==== TB_RF_TELEMETRY_NATIVE: %0d TEST(S) FAILED ====",
                errors
            );

        $finish;

    end

endmodule