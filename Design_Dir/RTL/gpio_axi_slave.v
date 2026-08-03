// =============================================================================
// gpio_axi_slave.v
// GPIO peripheral with AXI4-Lite slave port.
// Local address map (offsets, byte addresses, word-aligned):
//   0x00  GPIO_DATA_OUT  (R/W)  [31:0]  driven onto gpio_out when corresponding
//                                       GPIO_DIR bit = 1
//   0x04  GPIO_DATA_IN   (RO)   [31:0]  synchronized snapshot of gpio_in
//   0x08  GPIO_DIR       (R/W)  [31:0]  1 = pin is output, 0 = pin is input
//   0x0C  GPIO_STATUS    (RO)  [31:0]  bit0 = write_pulse (1-cycle strobe on any
//                                       accepted write to DATA_OUT, for LLM-3 to
//                                       observe activity), bits[31:1] = 0
// All other offsets: read -> 0x0 with SLVERR, write -> silently dropped (OKAY)
// No global address decoder here -- interconnect must present only addr[11:0]
// (see INTERFACE_SPEC.md section 1.1)
// =============================================================================
module gpio_axi_slave #(
    parameter GPIO_WIDTH = 32
)(
    input  wire                  s_axi_aclk,
    input  wire                  s_axi_aresetn,

    input  wire [11:0]           s_axi_awaddr,
    input  wire                  s_axi_awvalid,
    output reg                   s_axi_awready,

    input  wire [31:0]           s_axi_wdata,
    input  wire [3:0]            s_axi_wstrb,
    input  wire                  s_axi_wvalid,
    output reg                   s_axi_wready,

    output reg  [1:0]            s_axi_bresp,
    output reg                   s_axi_bvalid,
    input  wire                  s_axi_bready,

    input  wire [11:0]           s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output reg                   s_axi_arready,

    output reg  [31:0]           s_axi_rdata,
    output reg  [1:0]            s_axi_rresp,
    output reg                   s_axi_rvalid,
    input  wire                  s_axi_rready,

    // Peripheral-side pins
    output wire [GPIO_WIDTH-1:0] gpio_out,
    output wire [GPIO_WIDTH-1:0] gpio_oe,     // output-enable per bit (=GPIO_DIR)
    input  wire [GPIO_WIDTH-1:0] gpio_in
);

    localparam ADDR_DATA_OUT = 12'h000;
    localparam ADDR_DATA_IN  = 12'h004;
    localparam ADDR_DIR      = 12'h008;
    localparam ADDR_STATUS   = 12'h00C;

    // ---- Registers ----
    reg [31:0] reg_data_out;
    reg [31:0] reg_dir;
    reg [31:0] gpio_in_sync;
    reg        write_pulse;

    assign gpio_out = reg_data_out[GPIO_WIDTH-1:0];
    assign gpio_oe  = reg_dir[GPIO_WIDTH-1:0];

    // Synchronize input pins (2-FF synchronizer for metastability safety)
    reg [31:0] gpio_in_ff1;
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            gpio_in_ff1  <= 32'h0;
            gpio_in_sync <= 32'h0;
        end else begin
            gpio_in_ff1[GPIO_WIDTH-1:0]  <= gpio_in;
            gpio_in_sync                 <= gpio_in_ff1;
        end
    end

    // ---- Write channel FSM ----
    reg aw_hs, w_hs;
    wire write_en = aw_hs && w_hs;
    reg [11:0] awaddr_latched;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_awready  <= 1'b0;
            s_axi_wready   <= 1'b0;
            s_axi_bvalid   <= 1'b0;
            s_axi_bresp    <= 2'b00;
            aw_hs          <= 1'b0;
            w_hs           <= 1'b0;
            awaddr_latched <= 12'h0;
            reg_data_out   <= 32'h0;
            reg_dir        <= 32'h0;
            write_pulse    <= 1'b0;
        end else begin
            write_pulse <= 1'b0; // default: 1-cycle strobe

            // Address handshake
            if (s_axi_awvalid && !aw_hs && !s_axi_bvalid) begin
                s_axi_awready  <= 1'b1;
                awaddr_latched <= s_axi_awaddr;
                aw_hs          <= 1'b1;
            end else begin
                s_axi_awready <= 1'b0;
            end

            // Data handshake
            if (s_axi_wvalid && !w_hs && !s_axi_bvalid) begin
                s_axi_wready <= 1'b1;
                w_hs         <= 1'b1;
            end else begin
                s_axi_wready <= 1'b0;
            end

            // Commit write once both channels have handshaken
            if (aw_hs && w_hs && !s_axi_bvalid) begin
                case (awaddr_latched)
                    ADDR_DATA_OUT: begin
                        if (s_axi_wstrb[0]) reg_data_out[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_data_out[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_data_out[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) reg_data_out[31:24] <= s_axi_wdata[31:24];
                        write_pulse <= 1'b1;
                    end
                    ADDR_DIR: begin
                        if (s_axi_wstrb[0]) reg_dir[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_dir[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_dir[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) reg_dir[31:24] <= s_axi_wdata[31:24];
                    end
                    default: ; // read-only / unmapped: silently dropped
                endcase
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY always (never stall master)
                aw_hs        <= 1'b0;
                w_hs         <= 1'b0;
            end

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // ---- Read channel FSM ----
    reg [11:0] araddr_latched;
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_arready  <= 1'b0;
            s_axi_rvalid   <= 1'b0;
            s_axi_rdata    <= 32'h0;
            s_axi_rresp    <= 2'b00;
            araddr_latched <= 12'h0;
        end else begin
            if (s_axi_arvalid && !s_axi_arready && !s_axi_rvalid) begin
                s_axi_arready  <= 1'b1;
                araddr_latched <= s_axi_araddr;
            end else begin
                s_axi_arready <= 1'b0;
            end

            if (s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                case (araddr_latched)
                    ADDR_DATA_OUT: begin s_axi_rdata <= reg_data_out;  s_axi_rresp <= 2'b00; end
                    ADDR_DATA_IN:  begin s_axi_rdata <= gpio_in_sync;  s_axi_rresp <= 2'b00; end
                    ADDR_DIR:      begin s_axi_rdata <= reg_dir;       s_axi_rresp <= 2'b00; end
                    ADDR_STATUS:   begin s_axi_rdata <= {31'h0, write_pulse}; s_axi_rresp <= 2'b00; end
                    default:       begin s_axi_rdata <= 32'h0;         s_axi_rresp <= 2'b10; end
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
