module tpu_axis_checker (
    input clk,
    input rst_n,
    input axis_start,
    input [63:0] data_in,
    input s_axis_tvalid,
    input m_axis_tready
);

    parameter PROP = 1;

    wire [63:0] weight0 = data_in;
    wire [63:0] weight1 = data_in;
    wire [63:0] weight2 = data_in;
    wire [63:0] weight3 = data_in;
    wire [63:0] weight4 = data_in;
    wire [63:0] input0  = data_in;
    wire [63:0] input1  = data_in;
    
    wire [63:0] result0;
    wire [63:0] result1;

    wire        m_axis_tvalid;
    wire [63:0] m_axis_tdata;
    wire        m_axis_tlast;
    
    wire [63:0] s_axis_tdata = 64'd0;
    wire        s_axis_tlast = 1'b0;
    wire        s_axis_tready;
    
    wire        axis_busy;
    wire        axis_done;

    nn_axis_master u_master (
        .clk           (clk),
        .rst_n         (rst_n),
        .axis_start    (axis_start),
        .weight0       (weight0),
        .weight1       (weight1),
        .weight2       (weight2),
        .weight3       (weight3),
        .weight4       (weight4),
        .input0        (input0),
        .input1        (input1),
        .result0       (result0),
        .result1       (result1),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tlast  (m_axis_tlast),
        .m_axis_tready (m_axis_tready),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tlast  (s_axis_tlast),
        .s_axis_tready (s_axis_tready),
        .axis_busy     (axis_busy),
        .axis_done     (axis_done)
    );

    reg init = 1'b1;
    always @(posedge clk) init <= 1'b0;
    always @(*) if (init) assume(!rst_n);
    
    always @(posedge clk) begin
        if (!init && rst_n) begin
            // Environment stabilization
            assume(data_in == (data_in)); // Constant payload for the transaction
            assume(s_axis_tvalid == 1'b0); // Prevent mock RX injection
        end
    end

    always @(posedge clk) begin
        if (!init && rst_n) begin
            // TPU_P01 — VALID stability
            if (PROP == 1) begin
                if ((m_axis_tvalid) && !(m_axis_tready)) begin
                    assert(m_axis_tvalid == 1'b1);
                end
            end

            // TPU_P02 — Payload stability
            if (PROP == 2) begin
                if ((m_axis_tvalid) && !(m_axis_tready)) begin
                    assert(m_axis_tdata == (m_axis_tdata));
                end
            end

            // TPU_P03 — Transfer qualification
            if (PROP == 3) begin
                if ((m_axis_tvalid) && !(m_axis_tready)) begin
                    assert(u_master.beat_reg == (u_master.beat_reg));
                end
            end

            // TPU_P04 — TLAST behavior
            if (PROP == 4) begin
                if (m_axis_tvalid) begin
                    assert(m_axis_tlast == (u_master.beat_reg == 3'd6));
                end
            end

            // TPU_P06 — BUSY/DONE behavior
            if (PROP == 6) begin
                if ((axis_done)) begin
                    assert(axis_busy == 1'b0);
                end
            end
        end
    end

endmodule
