`timescale 1ns / 1ps

// ============================================================================
// Testbench: nn_axis_master        
// ============================================================================

module tb_nn_axis_master;

    reg clk;
    reg rst_n;

    reg start;

    reg [63:0] weight0;
    reg [63:0] weight1;
    reg [63:0] weight2;
    reg [63:0] weight3;
    reg [63:0] weight4;

    reg [63:0] input0;
    reg [63:0] input1;

    wire [63:0] m_axis_tdata;
    wire        m_axis_tvalid;
    wire        m_axis_tlast;
    reg         m_axis_tready;

    wire        s_axis_tvalid;
    wire        s_axis_tready;
    wire [63:0] s_axis_tdata;
    wire        s_axis_tlast;

    wire busy;
    wire tx_done;

    integer beat;
    integer errors;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------

    nn_axis_master dut (
        .clk          (clk),
        .rst_n        (rst_n),

        .axis_start   (start),

        .weight0      (weight0),
        .weight1      (weight1),
        .weight2      (weight2),
        .weight3      (weight3),
        .weight4      (weight4),

        .input0       (input0),
        .input1       (input1),

        .m_axis_tdata (m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast (m_axis_tlast),
        .m_axis_tready(m_axis_tready),

        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tdata (s_axis_tdata),
        .s_axis_tlast (s_axis_tlast),

        .axis_busy    (busy),
        .axis_done    (tx_done)
    );

    // -------------------------------------------------------------------------
    // Clock
    // -------------------------------------------------------------------------

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // AXIS monitor
    // -------------------------------------------------------------------------

    always @(posedge clk) begin

        if (rst_n && m_axis_tvalid && m_axis_tready) begin

            case (beat)

                0: if (m_axis_tdata !== weight0)
                       errors = errors + 1;

                1: if (m_axis_tdata !== weight1)
                       errors = errors + 1;

                2: if (m_axis_tdata !== weight2)
                       errors = errors + 1;

                3: if (m_axis_tdata !== weight3)
                       errors = errors + 1;

                4: if (m_axis_tdata !== weight4)
                       errors = errors + 1;

                5: if (m_axis_tdata !== input0)
                       errors = errors + 1;

                6: begin

                    if (m_axis_tdata !== input1)
                        errors = errors + 1;

                    if (!m_axis_tlast)
                        errors = errors + 1;

                end

            endcase

            $display("AXIS BEAT %0d : DATA=%h TLAST=%b",
                     beat, m_axis_tdata, m_axis_tlast);

            beat = beat + 1;
        end
    end

    // s_axis stub: drive two result beats after all TX beats done
    assign s_axis_tdata  = 64'hDEAD_BEEF_CAFE_F00D;
    assign s_axis_tlast  = (beat >= 7) ? 1'b1 : 1'b0;
    assign s_axis_tvalid = (beat >= 7) ? 1'b1 : 1'b0;

    // -------------------------------------------------------------------------
    // Test
    // -------------------------------------------------------------------------

    initial begin

        errors = 0;
        beat = 0;

        start = 0;
        m_axis_tready = 0;

        weight0 = 64'h1111_1111_1111_1111;
        weight1 = 64'h2222_2222_2222_2222;
        weight2 = 64'h3333_3333_3333_3333;
        weight3 = 64'h4444_4444_4444_4444;
        weight4 = 64'h5555_5555_5555_5555;

        input0  = 64'hAAAA_AAAA_AAAA_AAAA;
        input1  = 64'hBBBB_BBBB_BBBB_BBBB;

        // Reset.
        rst_n = 0;

        repeat (4) @(posedge clk);

        rst_n = 1;

        // Start.
        @(posedge clk);
        start = 1;

        @(posedge clk);
        start = 0;

        // Backpressure.
        repeat (3) @(posedge clk);

        m_axis_tready = 1;

        // Allow all remaining transfers.
        repeat (20) @(posedge clk);

        if (beat != 7) begin
            $display("FAIL: Expected 7 AXIS beats, received %0d", beat);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("TB_NN_AXIS_MASTER: ALL TESTS PASSED");
        else
            $display("TB_NN_AXIS_MASTER: %0d ERRORS", errors);

        $finish;
    end

endmodule