// =============================================================================
// control_status_axi_slave.v
// Global SoC control/status register block.
// Local address map:
//   0x00  SOC_ID       (RO)  fixed value 32'h56445030 ("VDP0") -- lets software
//                             confirm it is talking to this SoC/register bank.
//   0x04  SOC_CTRL     (R/W) bit0 = soc_soft_reset_req (self-clears 1 cycle
//                             after being set -- pulses soft_reset_o)
//   0x08  SOC_STATUS   (RO)  aggregated peripheral status snapshot, wired by
//                             the integration top-level (LLM-3): bit0..3 =
//                             {gpio_irq, sensor_alarm, rf_link_up, vdp_frame_flag}
// All other offsets: read -> 0 SLVERR, write -> dropped OKAY.
// No global address decoder here (see INTERFACE_SPEC.md).
// =============================================================================
module control_status_axi_slave (
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

    // Aggregated status inputs, wired by the integration top level (LLM-3)
    input  wire        gpio_irq_i,
    input  wire        sensor_alarm_i,
    input  wire        rf_link_up_i,
    input  wire        vdp_frame_flag_i,

    output reg         soft_reset_o   // 1-cycle pulse
);

    localparam ADDR_ID     = 12'h000;
    localparam ADDR_CTRL   = 12'h004;
    localparam ADDR_STATUS = 12'h008;
    localparam [31:0] SOC_ID_VALUE = 32'h56445030; // "VDP0"

    wire [31:0] status_word = {28'h0, vdp_frame_flag_i, rf_link_up_i, sensor_alarm_i, gpio_irq_i};

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
            soft_reset_o   <= 1'b0;
        end else begin
            soft_reset_o <= 1'b0; // default: 1-cycle pulse only

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
                if (awaddr_latched == ADDR_CTRL && s_axi_wstrb[0] && s_axi_wdata[0])
                    soft_reset_o <= 1'b1;
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
                    ADDR_ID:     begin s_axi_rdata <= SOC_ID_VALUE; s_axi_rresp <= 2'b00; end
                    ADDR_CTRL:   begin s_axi_rdata <= 32'h0;        s_axi_rresp <= 2'b00; end // self-clearing, reads back 0
                    ADDR_STATUS: begin s_axi_rdata <= status_word;  s_axi_rresp <= 2'b00; end
                    default:     begin s_axi_rdata <= 32'h0;        s_axi_rresp <= 2'b10; end
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
