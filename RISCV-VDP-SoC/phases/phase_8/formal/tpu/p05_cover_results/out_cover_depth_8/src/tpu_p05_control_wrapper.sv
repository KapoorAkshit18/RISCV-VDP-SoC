module tpu_p05_control_wrapper (
    input wire clk,
    input wire rst_n,
    
    input wire         bus_req,
    input wire         bus_write,
    input wire [31:0]  bus_addr,
    input wire [31:0]  bus_wdata,
    input wire [3:0]   bus_strb,
    
    input wire         m_axis_tready,
    
    output wire        axis_start,
    output wire        axis_busy,
    output wire        m_axis_tvalid
);

    wire        bus_ready;
    wire [31:0] bus_rdata;
    wire        axis_done;
    
    wire        m_axis_tlast;
    
    // Abstract the 576-bit datapath completely to prevent SMT solver explosion.
    // 1. Leave nn_axi_wrapper datapath outputs unconnected so Yosys prunes the MMIO mux.
    // 2. Feed constant 0 to nn_axis_master datapath inputs so Yosys prunes the beat mux.
    
    nn_axi_wrapper u_wrapper (
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
        .axis_busy  (axis_busy),
        .axis_done  (axis_done),
        
        // DATAPATH SEVERED
        .weight0    (),
        .weight1    (),
        .weight2    (),
        .weight3    (),
        .weight4    (),
        .input0     (),
        .input1     (),
        .result0    (64'd0),
        .result1    (64'd0)
    );

    nn_axis_master u_master (
        .clk           (clk),
        .rst_n         (rst_n),
        .axis_start    (axis_start),
        
        // DATAPATH CONSTANTS
        .weight0       (64'd0),
        .weight1       (64'd0),
        .weight2       (64'd0),
        .weight3       (64'd0),
        .weight4       (64'd0),
        .input0        (64'd0),
        .input1        (64'd0),
        .result0       (),
        .result1       (),
        
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tdata  (),
        .m_axis_tlast  (m_axis_tlast),
        .m_axis_tready (m_axis_tready),
        
        .s_axis_tvalid (1'b0),
        .s_axis_tdata  (64'd0),
        .s_axis_tlast  (1'b0),
        .s_axis_tready (),
        
        .axis_busy     (axis_busy),
        .axis_done     (axis_done)
    );

endmodule
