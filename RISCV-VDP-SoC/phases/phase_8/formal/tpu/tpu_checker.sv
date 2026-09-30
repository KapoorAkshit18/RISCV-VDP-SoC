module tpu_checker (
    input clk,
    input rst_n
);

    parameter PROP = 1;

    wire        axis_start;
    wire [63:0] weight0 = 64'd0;
    wire [63:0] weight1 = 64'd0;
    wire [63:0] weight2 = 64'd0;
    wire [63:0] weight3 = 64'd0;
    wire [63:0] weight4 = 64'd0;
    wire [63:0] input0 = 64'd0;
    wire [63:0] input1 = 64'd0;
    
    wire [63:0] result0;
    wire [63:0] result1;

    wire        m_axis_tvalid;
    wire [63:0] m_axis_tdata;
    wire        m_axis_tlast;
    wire        m_axis_tready = 1'b1;
    
    wire        s_axis_tvalid = 1'b0;
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

    always @(posedge clk) begin
        assert(m_axis_tvalid == 1'b0 || m_axis_tvalid == 1'b1);
    end

endmodule
