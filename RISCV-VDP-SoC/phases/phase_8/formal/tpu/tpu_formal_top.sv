module tpu_formal_top #(
    parameter PROP = 1
) (
    input clk,
    input resetn,
    
    input         bus_req,
    input         bus_write,
    input  [31:0] bus_addr,
    input  [31:0] bus_wdata,
    input  [ 3:0] bus_strb,

    input         m_axis_tready,
    input         s_axis_tvalid,
    input  [63:0] s_axis_tdata,
    input         s_axis_tlast
);

    wire        bus_ready;
    wire [31:0] bus_rdata;

    wire        axis_start;
    wire        axis_busy;
    
    wire [63:0] weight0, weight1, weight2, weight3, weight4;
    wire [63:0] input0, input1;
    wire [63:0] result0, result1;

    wire        m_axis_tvalid;
    wire [63:0] m_axis_tdata;
    wire        m_axis_tlast;
    
    wire        s_axis_tready;

    nn_axi_wrapper u_wrapper (
        .clk        (clk),
        .rst_n      (resetn),
        .bus_req    (bus_req),
        .bus_write  (bus_write),
        .bus_addr   (bus_addr),
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

    reg init = 1'b1;
    always @(posedge clk) init <= 1'b0;

    always @(*) if (init) assume(!resetn);

    // Provide a small environment assumption for the abstract master bus
    always @(posedge clk) begin
        if (!init && resetn) begin
            // Crucial: Restrict the address space to the MMIO window so Z3 doesn't explore 4GB!
            // Address is local. Max mapped register is 0x24 (RESULT1_H).
            if (bus_req) assume(bus_addr[31:8] == 24'd0);
            
            // Handshake compliance
            if ($past(bus_req) && !$past(bus_ready)) begin
                assume(bus_req == 1'b1);
                assume(bus_addr == $past(bus_addr));
                assume(bus_write == $past(bus_write));
                if ($past(bus_write)) begin
                    assume(bus_wdata == $past(bus_wdata));
                    assume(bus_strb == $past(bus_strb));
                end
            end
        end
    end

    // ----------------------------------------------------------------------
    // PROPERTIES
    // ----------------------------------------------------------------------
    always @(posedge clk) begin
        if (!init && resetn) begin

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
            // A transfer occurs only when VALID && READY
            if (PROP == 3) begin
                // If VALID is 1 but READY is 0, the beat counter doesn't change
                if ($past(m_axis_tvalid) && !$past(m_axis_tready)) begin
                    assert(u_master.beat_reg == $past(u_master.beat_reg));
                end
            end

            // TPU_P04 — TLAST behavior
            if (PROP == 4) begin
                // TLAST is exactly true on the 7th beat (beat_reg == 6) when VALID is true.
                if (m_axis_tvalid) begin
                    assert(m_axis_tlast == (u_master.beat_reg == 3'd6));
                end
            end

            // TPU_P05 — START behavior
            // MMIO START triggers AXI transaction.
            if (PROP == 5) begin
                if ($past(bus_req) && $past(bus_write) && $past(bus_addr[7:0]) == 8'h00 && $past(bus_wdata[0]) && !$past(axis_busy)) begin
                    assert(axis_start == 1'b1);
                end
            end

            // TPU_P06 — BUSY/DONE behavior
            // When done pulses, busy is cleared
            if (PROP == 6) begin
                if ($past(u_master.axis_done)) begin
                    assert(axis_busy == 1'b0);
                end
            end

        end
    end

endmodule
