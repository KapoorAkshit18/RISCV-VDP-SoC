// =============================================================================
// rf_telemetry_axi_slave.v
// RF link telemetry window, exposed over AXI4-Lite.
// Local address map:
//   0x00  RF_RSSI       (RO)  [7:0]   signed dBm (two's complement, e.g. -70 = 0xBA)
//   0x04  RF_LINK_STAT  (RO)  [31:0]  bit0=link_up, bit1=link_error, bit2=carrier_detect
//   0x08  RF_CONTROL    (R/W) [31:0]  bit0=rf_enable (drives rf_enable_o pin)
//   0x0C  RF_ID         (RO)  [31:0]  fixed peripheral ID = 32'h52465430 ("RFT0")
// RF_CONTROL is the only writable register. All other offsets: read -> 0 SLVERR,
// write -> dropped (OKAY). No global address decoder here.
// =============================================================================
module rf_telemetry_axi_slave (
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,

    input  wire [11:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,

    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,

    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [11:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,

    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    // Peripheral-side pins
    input  wire [7:0]  rssi_dbm_i,        // signed
    input  wire        link_up_i,
    input  wire        link_error_i,
    input  wire        carrier_detect_i,
    output wire        rf_enable_o
);

    localparam ADDR_RSSI      = 12'h000;
    localparam ADDR_LINKSTAT  = 12'h004;
    localparam ADDR_CONTROL   = 12'h008;
    localparam ADDR_ID        = 12'h00C;
    localparam [31:0] RF_ID_VALUE = 32'h52465430; // "RFT0"

    // Synchronizers for external RF-front-end status pins
    reg [7:0] rssi_ff1, rssi_sync;
    reg link_up_ff1, link_up_sync;
    reg link_err_ff1, link_err_sync;
    reg carrier_ff1, carrier_sync;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            rssi_ff1 <= 8'h0; rssi_sync <= 8'h0;
            link_up_ff1 <= 1'b0; link_up_sync <= 1'b0;
            link_err_ff1 <= 1'b0; link_err_sync <= 1'b0;
            carrier_ff1 <= 1'b0; carrier_sync <= 1'b0;
        end else begin
            rssi_ff1 <= rssi_dbm_i;           rssi_sync <= rssi_ff1;
            link_up_ff1 <= link_up_i;         link_up_sync <= link_up_ff1;
            link_err_ff1 <= link_error_i;     link_err_sync <= link_err_ff1;
            carrier_ff1 <= carrier_detect_i;  carrier_sync <= carrier_ff1;
        end
    end

    wire [31:0] link_status_word = {29'h0, carrier_sync, link_err_sync, link_up_sync};

    // R/W control register
    reg reg_rf_enable;
    assign rf_enable_o = reg_rf_enable;

    // ---- Write channel ----
    reg aw_hs, w_hs;
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
            reg_rf_enable  <= 1'b0;
        end else begin
            if (s_axi_awvalid && !aw_hs && !s_axi_bvalid) begin
                s_axi_awready  <= 1'b1;
                awaddr_latched <= s_axi_awaddr;
                aw_hs          <= 1'b1;
            end else s_axi_awready <= 1'b0;

            if (s_axi_wvalid && !w_hs && !s_axi_bvalid) begin
                s_axi_wready <= 1'b1;
                w_hs         <= 1'b1;
            end else s_axi_wready <= 1'b0;

            if (aw_hs && w_hs && !s_axi_bvalid) begin
                if (awaddr_latched == ADDR_CONTROL && s_axi_wstrb[0])
                    reg_rf_enable <= s_axi_wdata[0];
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
                aw_hs <= 1'b0; w_hs <= 1'b0;
            end
            if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 1'b0;
        end
    end

    // ---- Read channel ----
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
            end else s_axi_arready <= 1'b0;

            if (s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                case (araddr_latched)
                    ADDR_RSSI:     begin s_axi_rdata <= {24'h0, rssi_sync}; s_axi_rresp <= 2'b00; end
                    ADDR_LINKSTAT: begin s_axi_rdata <= link_status_word;   s_axi_rresp <= 2'b00; end
                    ADDR_CONTROL:  begin s_axi_rdata <= {31'h0, reg_rf_enable}; s_axi_rresp <= 2'b00; end
                    ADDR_ID:       begin s_axi_rdata <= RF_ID_VALUE;        s_axi_rresp <= 2'b00; end
                    default:       begin s_axi_rdata <= 32'h0;              s_axi_rresp <= 2'b10; end
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
