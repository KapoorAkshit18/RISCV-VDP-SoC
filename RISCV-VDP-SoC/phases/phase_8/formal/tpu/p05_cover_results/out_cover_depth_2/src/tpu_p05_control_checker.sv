module tpu_p05_control_checker (
    input clk,
    input rst_n,
    
    input         bus_req,
    input         bus_write,
    input  [31:0] bus_addr,
    input         bus_wdata_0,
    input         bus_strb_0,
    input         m_axis_tready
);

    parameter PROP = 1; // 1 to 5 for P05.1 to P05.5

    // Reconstruct the bus signals to isolate the control logic
    wire [31:0] bus_wdata = {31'd0, bus_wdata_0};
    wire [ 3:0] bus_strb  = {3'd0,  bus_strb_0};

    wire axis_start;
    wire axis_busy;
    wire m_axis_tvalid;

    // Instantiate the wrapper
    tpu_p05_control_wrapper u_wrapper (
        .clk           (clk),
        .rst_n         (rst_n),
        .bus_req       (bus_req),
        .bus_write     (bus_write),
        .bus_addr      (bus_addr),
        .bus_wdata     (bus_wdata),
        .bus_strb      (bus_strb),
        .m_axis_tready (m_axis_tready),
        .axis_start    (axis_start),
        .axis_busy     (axis_busy),
        .m_axis_tvalid (m_axis_tvalid)
    );
    
    // START condition helper
    wire is_control_reg = (bus_addr[7:0] == 8'h00);
    wire start_request = bus_req && bus_write && is_control_reg && bus_strb_0 && bus_wdata_0;

    reg init = 1'b1;
    always @(posedge clk) init <= 1'b0;

    reg past_valid = 1'b0;
    always @(posedge clk) past_valid <= 1'b1;

    always @(*) if (init) assume(!rst_n);
    always @(*) if (!init) assume(rst_n);

    always @(posedge clk) begin
        if (!init && rst_n) begin
            
            // Assume we only access the control register to avoid state explosion
            if (bus_req) begin
                assume(bus_addr[31:8] == 24'd0);
                assume(bus_addr[7:0] == 8'h00);
            end

            // P05.1 — START Acceptance
            if (PROP == 1) begin
                if (past_valid && $past(rst_n) && $past(start_request) && !$past(axis_busy)) begin
                    assert(axis_start == 1'b1);
                end
            end
            
            // P05.2 — BUSY Response
            if (PROP == 2) begin
                if (past_valid && $past(axis_start)) begin
                    assert(axis_busy == 1'b1);
                end
            end
            
            // P05.3 — No Spurious Start
            if (PROP == 3) begin
                if (past_valid && axis_start) begin
                    assert($past(start_request) && !$past(axis_busy));
                end
            end
            
            // P05.4 — START While BUSY
            // RTL ignores the start if busy is true.
            if (PROP == 4) begin
                if (past_valid && $past(rst_n) && $past(start_request) && $past(axis_busy)) begin
                    assert(axis_start == 1'b0);
                end
            end
            
            // P05.5 — Transaction Initiation
            if (PROP == 5) begin
                if (past_valid && $past(axis_start)) begin
                    assert(m_axis_tvalid == 1'b1);
                end
            end
        end
    end

    // Cover: demonstrate START event is reachable
    always @(posedge clk) begin
        if (!init && rst_n) begin
            cover(axis_start);
            cover(m_axis_tvalid);
        end
    end

endmodule
