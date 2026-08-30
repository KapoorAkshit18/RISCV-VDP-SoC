`timescale 1ns/1ps
// =============================================================================
// tb_control_status.v
// Self-checking testbench for control_status_native_slave
//
// PicoRV32 native memory bus:
//   mem_valid
//   mem_ready
//   mem_addr
//   mem_wdata
//   mem_wstrb
//   mem_rdata
// =============================================================================

module tb_control_status;

    reg clk = 0;
    reg resetn;

    // ------------------------------------------------------------------------
    // PicoRV32 native memory interface
    // ------------------------------------------------------------------------

    reg         mem_valid;
    reg         mem_instr;
    wire        mem_ready;

    reg  [11:0] mem_addr;
    reg  [31:0] mem_wdata;
    reg  [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;

    // ------------------------------------------------------------------------
    // Aggregated status inputs
    // ------------------------------------------------------------------------

    reg gpio_irq;
    reg sensor_alarm;
    reg rf_link_up;
    reg vdp_frame_flag;

    wire soft_reset;

    integer errors = 0;

    // ------------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------------

    control_status_native_slave dut (
        .clk              (clk),
        .resetn           (resetn),

        .mem_valid        (mem_valid),
        .mem_instr        (mem_instr),
        .mem_ready        (mem_ready),
        .mem_addr         (mem_addr),
        .mem_wdata        (mem_wdata),
        .mem_wstrb        (mem_wstrb),
        .mem_rdata        (mem_rdata),

        .gpio_irq_i       (gpio_irq),
        .sensor_alarm_i   (sensor_alarm),
        .rf_link_up_i     (rf_link_up),
        .vdp_frame_flag_i (vdp_frame_flag),

        .soft_reset_o     (soft_reset)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    // =========================================================================
    // Native WRITE
    // =========================================================================

    task native_write(
        input [11:0] addr,
        input [31:0] data,
        input [3:0]  strb
    );
        begin

            @(posedge clk);

            mem_addr  <= addr;
            mem_wdata <= data;
            mem_wstrb <= strb;
            mem_instr <= 1'b0;
            mem_valid <= 1'b1;

            // Wait until slave completes transaction
            @(posedge clk);

            while (!mem_ready)
                @(posedge clk);

            mem_valid <= 1'b0;
            mem_wstrb <= 4'b0000;

            @(posedge clk);

        end
    endtask

    // =========================================================================
    // Native READ
    // =========================================================================

    task native_read(
        input  [11:0] addr,
        output [31:0] data
    );
        begin

            @(posedge clk);

            mem_addr  <= addr;
            mem_wdata <= 32'h0000_0000;
            mem_wstrb <= 4'b0000;
            mem_instr <= 1'b0;
            mem_valid <= 1'b1;

            @(posedge clk);

            while (!mem_ready)
                @(posedge clk);

            data = mem_rdata;

            mem_valid <= 1'b0;

            @(posedge clk);

        end
    endtask

    reg [31:0] rd_data;

    // =========================================================================
    // TEST SEQUENCE
    // =========================================================================

    initial begin

        // ------------------------------------------------------------
        // Initial conditions
        // ------------------------------------------------------------

        resetn = 1'b0;

        mem_valid = 1'b0;
        mem_instr = 1'b0;
        mem_addr  = 12'h000;
        mem_wdata = 32'h0000_0000;
        mem_wstrb = 4'b0000;

        gpio_irq       = 1'b0;
        sensor_alarm   = 1'b0;
        rf_link_up     = 1'b1;
        vdp_frame_flag = 1'b0;

        // ------------------------------------------------------------
        // Reset
        // ------------------------------------------------------------

        repeat (4)
            @(posedge clk);

        resetn = 1'b1;

        repeat (2)
            @(posedge clk);
        #1;
        // ============================================================
        // TEST 1: SOC_ID
        // ============================================================

        native_read(12'h000, rd_data);

        if (rd_data === 32'h5644_5030)
            $display("PASS: SOC_ID = %h (\"VDP0\")", rd_data);
        else begin
            $display("FAIL: SOC_ID = %h (expected 56445030)", rd_data);
            errors = errors + 1;
        end

        // ============================================================
        // TEST 2: SOC_STATUS
        // rf_link_up = 1
        // all others = 0
        //
        // bit mapping:
        // bit3 = vdp_frame_flag
        // bit2 = rf_link_up
        // bit1 = sensor_alarm
        // bit0 = gpio_irq
        //
        // Expected = 0100 binary
        // ============================================================

        native_read(12'h008, rd_data);

        if (rd_data === 32'b0100)
            $display("PASS: SOC_STATUS = %b (rf_link_up=1, rest=0)", rd_data);
        else begin
            $display("FAIL: SOC_STATUS = %b (expected 0100)", rd_data);
            errors = errors + 1;
        end

        // ============================================================
        // TEST 3: soft_reset_o
        // ============================================================

        native_write(
            12'h004,
            32'h0000_0001,
            4'hF
        );

        // soft_reset is generated for the transaction commit cycle.
        //
        // Because native_write waits for mem_ready and then advances
        // another clock, the pulse may already have ended here.
        //
        // Therefore explicitly perform a transaction and monitor it.

        @(posedge clk);
        #1;
        mem_addr  <= 12'h004;
        mem_wdata <= 32'h0000_0001;
        mem_wstrb <= 4'hF;
        mem_instr <= 1'b0;
        mem_valid <= 1'b1;

        @(posedge clk);
        #1;
        if (mem_ready === 1'b1) begin

            if (soft_reset === 1'b1)
                $display("PASS: soft_reset_o asserted on SOC_CTRL[0]=1 write");
            else begin
                $display("FAIL: soft_reset_o = %b, expected 1", soft_reset);
                errors = errors + 1;
            end

        end
        else begin

            $display("FAIL: mem_ready did not assert for SOC_CTRL write");
            errors = errors + 1;

        end

        mem_valid <= 1'b0;
        mem_wstrb <= 4'b0000;

        // Pulse must clear
        @(posedge clk);
        #1;
        if (soft_reset === 1'b0)
            $display("PASS: soft_reset_o self-cleared after 1 cycle");
        else begin
            $display(
                "FAIL: soft_reset_o still high (%b), expected 0",
                soft_reset
            );
            errors = errors + 1;
        end

        // ============================================================
        // TEST 4: SOC_CTRL reads back zero
        // ============================================================

        native_read(12'h004, rd_data);

        if (rd_data === 32'h0000_0000)
            $display("PASS: SOC_CTRL reads back 0");
        else begin
            $display(
                "FAIL: SOC_CTRL readback = %h (expected 0)",
                rd_data
            );
            errors = errors + 1;
        end

        // ============================================================
        // TEST 5: Live SOC_STATUS
        //
        // gpio_irq       = 0
        // sensor_alarm   = 1
        // rf_link_up     = 1
        // vdp_frame_flag = 1
        //
        // Expected:
        // bit3 = 1
        // bit2 = 1
        // bit1 = 1
        // bit0 = 0
        //
        // => 1110
        // ============================================================

        sensor_alarm   = 1'b1;
        vdp_frame_flag = 1'b1;

        @(posedge clk);
        #1;
        native_read(12'h008, rd_data);

        if (rd_data === 32'b1110)
            $display(
                "PASS: SOC_STATUS reflects live status = %b",
                rd_data
            );
        else begin
            $display(
                "FAIL: SOC_STATUS = %b (expected 1110)",
                rd_data
            );
            errors = errors + 1;
        end

        // ============================================================
        // TEST 6: Unmapped address
        //
        // Native bus has no SLVERR response.
        // Therefore unmapped read must simply return 0 and complete.
        // ============================================================

        native_read(12'h0F4, rd_data);

        if (rd_data === 32'h0000_0000)
            $display(
                "PASS: unmapped offset 0x0F4 reads 0 and completes normally"
            );
        else begin
            $display(
                "FAIL: unmapped offset returned %h (expected 0)",
                rd_data
            );
            errors = errors + 1;
        end

        // ============================================================
        // FINAL RESULT
        // ============================================================

        if (errors == 0)
            $display("==== TB_CONTROL_STATUS: ALL TESTS PASSED ====");
        else
            $display(
                "==== TB_CONTROL_STATUS: %0d TEST(S) FAILED ====",
                errors
            );

        $finish;

    end

endmodule