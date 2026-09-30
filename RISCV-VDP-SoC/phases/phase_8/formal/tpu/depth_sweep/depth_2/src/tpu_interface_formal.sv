module tpu_bind_formal (
    input clk,
    input resetn,
    // Native Slave IF
    input         bus_req,
    input         bus_write,
    input  [11:0] bus_addr,
    input  [31:0] bus_wdata,
    input  [ 3:0] bus_strb,
    input         bus_ready,
    input  [31:0] bus_rdata,

    // AXI Master IF
    input         m_axis_tvalid,
    input  [63:0] m_axis_tdata,
    input         m_axis_tlast,
    input         m_axis_tready,

    input         s_axis_tvalid,
    input  [63:0] s_axis_tdata,
    input         s_axis_tlast,
    input         s_axis_tready
);

    reg init = 1'b1;
    always @(posedge clk) init <= 1'b0;

    // Reset assumption
    always @(*) if (init) assume(!resetn);

    always @(posedge clk) begin
        if (!init && resetn) begin
            // ----------------------------------------------------
            // COVERS
            // ----------------------------------------------------
            // TPU_C01: Successful native bus read
            cover(bus_req && !bus_write && bus_ready);
            // TPU_C02: Successful AXI transmit
            cover(m_axis_tvalid && m_axis_tready);
            // TPU_C03: Full AXI burst completion
            cover(m_axis_tvalid && m_axis_tready && m_axis_tlast);

            // ----------------------------------------------------
            // ASSERTIONS
            // ----------------------------------------------------
            // TPU_A01: Valid/Ready stability (AXI standard)
            // m_axis is driven by TPU, so we ASSERT its stability.
            if ($past(m_axis_tvalid) && !$past(m_axis_tready)) begin
                assert(m_axis_tvalid == 1'b1);
                assert(m_axis_tdata == $past(m_axis_tdata));
                assert(m_axis_tlast == $past(m_axis_tlast));
            end
        end
    end
endmodule

bind tpu_interface_formal tpu_bind_formal u_checker (
    .clk(clk),
    .resetn(resetn),
    .bus_req(bus_req),
    .bus_write(bus_write),
    .bus_addr(bus_addr),
    .bus_wdata(bus_wdata),
    .bus_strb(bus_strb),
    .bus_ready(bus_ready),
    .bus_rdata(bus_rdata),
    
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tready(m_axis_tready),
    
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tready(s_axis_tready)
);

// Minimal environment wrapper
module tpu_interface_formal (
    input clk,
    input resetn,
    
    input         bus_req,
    input         bus_write,
    input  [11:0] bus_addr,
    input  [31:0] bus_wdata,
    input  [ 3:0] bus_strb
);
    wire        bus_ready;
    wire [31:0] bus_rdata;

    wire        m_axis_tvalid;
    wire [63:0] m_axis_tdata;
    wire        m_axis_tlast;
    
    wire        s_axis_tready;

    // Deterministic mock AXI Source
    wire [63:0] s_axis_tdata = 64'd0;
    wire        s_axis_tlast = 1'b0;

    // Deterministic mock AXI Sink (always ready)
    wire m_axis_tready = 1'b1;
    
    // Deterministic mock AXI Source (never valid to prevent arbitrary rx injection for now)
    wire s_axis_tvalid = 1'b0;

    // Instantiate ONLY the digital interfaces, NOT the neural network datapath.
    // We create a structural stand-in for tpu_axis_top.
    wire axis_start;
    wire axis_busy;
    
    wire [63:0] weight0, weight1, weight2, weight3, weight4;
    wire [63:0] input0, input1;
    wire [63:0] result0, result1;


    nn_axi_wrapper u_wrapper (
        .clk        (clk),
        .rst_n      (resetn),
        .bus_req    (bus_req),
        .bus_write  (bus_write),
        .bus_addr   ({20'b0, bus_addr}),
        .bus_wdata  (bus_wdata),
        .bus_strb   (bus_strb),
        .bus_ready  (bus_ready),
        .bus_rdata  (bus_rdata),
        
        .axis_start (axis_start),
        .axis_busy  (axis_busy),
        .weight0    (weight0),
        .weight1    (weight1),
        .weight2    (weight2),
        .weight3    (weight3),
        .weight4    (weight4),
        .input0     (input0),
        .input1     (input1),
        .result0    (result0),
        .result1    (result1)
    );

    nn_axis_master u_master (
        .clk           (clk),
        .rst_n         (resetn),
        
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
        .axis_done     ()
    );

endmodule
