module tpu_checker (
    input clk,
    input rst_n,
    
    input         axis_start,
    
    input [63:0]  weight0,
    input [63:0]  weight1,
    input [63:0]  weight2,
    input [63:0]  weight3,
    input [63:0]  weight4,
    input [63:0]  input0,
    input [63:0]  input1,
    
    input [63:0]  result0,
    input [63:0]  result1,

    input         m_axis_tvalid,
    input [63:0]  m_axis_tdata,
    input         m_axis_tlast,
    input         m_axis_tready,
    
    input         s_axis_tvalid,
    input [63:0]  s_axis_tdata,
    input         s_axis_tlast,
    input         s_axis_tready,
    
    input         axis_busy,
    input         axis_done,
    input [2:0]   beat_reg
);

    parameter PROP = 1;

    reg init = 1'b1;
    always @(posedge clk) init <= 1'b0;

    always @(*) if (init) assume(!rst_n);

    // Environment: Deterministic mock AXI Sink
    always @(*) assume(m_axis_tready == 1'b1);

    // Environment: Deterministic mock AXI Source (no async RX injection for TX checks)
    always @(*) assume(s_axis_tvalid == 1'b0);

    always @(posedge clk) begin
        if (!init && rst_n) begin
            assume(weight0 == 64'd0);
            assume(weight1 == 64'd0);
            assume(weight2 == 64'd0);
            assume(weight3 == 64'd0);
            assume(weight4 == 64'd0);
            assume(input0 == 64'd0);
            assume(input1 == 64'd0);
            assume(result0 == 64'd0);
            assume(result1 == 64'd0);
            assume(axis_start == $past(axis_start));

            // TPU_P01 — VALID stability
            if (PROP == 1) begin
                if ($past(m_axis_tvalid) && !$past(m_axis_tready)) begin
                    assert(m_axis_tvalid == 1'b1);
                end
            end

            // TPU_P02 — Payload stability
            if (PROP == 2) begin
                if ($past(m_axis_tvalid) && !$past(m_axis_tready)) begin
                    assert(m_axis_tdata == $past(m_axis_tdata));
                end
            end

            // TPU_P03 — Transfer qualification
            if (PROP == 3) begin
                if ($past(m_axis_tvalid) && !$past(m_axis_tready)) begin
                    assert(beat_reg == $past(beat_reg));
                end
            end

            // TPU_P04 — TLAST behavior
            if (PROP == 4) begin
                if (m_axis_tvalid) begin
                    assert(m_axis_tlast == (beat_reg == 3'd6));
                end
            end

            // TPU_P06 — BUSY/DONE behavior
            if (PROP == 6) begin
                if ($past(axis_done)) begin
                    assert(axis_busy == 1'b0);
                end
            end

        end
    end

endmodule

bind nn_axis_master tpu_checker #(
    .PROP(`PROP)
) checker_inst (
    .clk(clk),
    .rst_n(rst_n),
    .axis_start(axis_start),
    .weight0(weight0),
    .weight1(weight1),
    .weight2(weight2),
    .weight3(weight3),
    .weight4(weight4),
    .input0(input0),
    .input1(input1),
    .result0(result0),
    .result1(result1),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tready(m_axis_tready),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tready(s_axis_tready),
    .axis_busy(axis_busy),
    .axis_done(axis_done),
    .beat_reg(beat_reg)
);
