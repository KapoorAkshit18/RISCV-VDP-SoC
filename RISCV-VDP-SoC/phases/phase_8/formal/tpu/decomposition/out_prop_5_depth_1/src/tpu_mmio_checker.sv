module tpu_mmio_checker (
    input clk,
    input rst_n,
    
    input         bus_req,
    input         bus_write,
    input  [31:0] bus_addr,
    input  [31:0] bus_wdata,
    input  [ 3:0] bus_strb,
    input         axis_busy
);

    parameter PROP = 5;

    wire        bus_ready;
    wire [31:0] bus_rdata;

    wire        axis_start;
    
    // We only care about REG_CONTROL (0x00) for START.
    // The other registers are irrelevant for this property, so we let Yosys prune them.
    wire [63:0] weight0, weight1, weight2, weight3, weight4;
    wire [63:0] input0, input1;
    wire [63:0] result0 = 64'd0;
    wire [63:0] result1 = 64'd0;

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

    reg init = 1'b1;
    always @(posedge clk) init <= 1'b0;

    always @(*) if (init) assume(!rst_n);

    always @(*) begin
        // Unconditional address constraints to prune the massive combinational mux space
        assume(bus_addr[31:8] == 24'd0);
        assume(bus_addr[7:0] == 8'h00 || bus_addr[7:0] == 8'h04);
        // Tie off unused data inputs to prevent payload explosion
        assume(bus_wdata[31:1] == 31'd0);
    end

    always @(posedge clk) begin
        if (!init && rst_n) begin

            // P05 — START behavior
            if (PROP == 5) begin
                if ((bus_req) && (bus_write) && (bus_addr[7:0]) == 8'h00 && (bus_wdata[0]) && !(axis_busy)) begin
                    assert(axis_start == 1'b1);
                end
            end
        end
    end

endmodule
