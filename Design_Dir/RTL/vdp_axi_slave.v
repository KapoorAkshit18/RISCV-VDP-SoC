// =============================================================================
// vdp_axi_slave.v
// Video Display Processor: wraps vga_timing_gen with an AXI4-Lite register
// interface and a simple programmable pixel-color generator.
//
// NOTE ON SCOPE: a full framebuffer-based VDP (pixel memory, DMA fetch, sprite/
// tile engines) is a much larger design than fits this increment. This module
// delivers the required timing generator + programmable display/control
// registers + RGB output per the spec, using a lightweight test-pattern
// generator (solid color OR an X/Y-derived gradient) in place of a framebuffer.
// A framebuffer read-port can be added later behind the same register map
// without breaking this interface (VDP_COLOR would become a palette/base-color
// register); documented here so LLM-1/LLM-3 know this is intentional, not an
// omission.
//
// Local address map:
//   0x00  VDP_CTRL    (R/W) bit0 = display_enable
//                            bit1 = pattern_mode (0 = solid VDP_COLOR, 1 = XY gradient test pattern)
//   0x04  VDP_STATUS  (RO/W1C) bit0 = hsync (1 = active/asserted, logical-high for sw convenience)
//                               bit1 = vsync (1 = active/asserted)
//                               bit2 = video_active
//                               bit3 = frame_flag (sticky, set once per frame @ h=0,v=0;
//                                                   write 1 to this bit to clear it)
//   0x08  VDP_HCOUNT  (RO)  [11:0] current horizontal pixel counter (0..799)
//   0x0C  VDP_VCOUNT  (RO)  [11:0] current vertical line counter (0..524)
//   0x10  VDP_COLOR   (R/W) [23:0] {R[23:16],G[15:8],B[7:0]} solid color used when pattern_mode=0
// All other offsets: read -> 0 SLVERR, write -> dropped OKAY.
// No global address decoder here (see INTERFACE_SPEC.md).
// =============================================================================
module vdp_axi_slave (
    input  wire        s_axi_aclk,      // register-bus clock domain
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

    // Video-side pins (this simplified integration assumes pixel_clk == s_axi_aclk;
    // if LLM-1/LLM-3 need a separate pixel clock domain, that is a documented
    // interface change: add a CDC (dual-clock FIFO or 2-FF sync on the RO status
    // bits) between s_axi_aclk and pixel_clk.)
    input  wire        pixel_clk,
    output wire        hsync_o,
    output wire        vsync_o,
    output wire [11:0] pixel_x_o,
    output wire [11:0] pixel_y_o,
    output wire [7:0]  rgb_r_o,
    output wire [7:0]  rgb_g_o,
    output wire [7:0]  rgb_b_o
);

    localparam ADDR_CTRL   = 12'h000;
    localparam ADDR_STATUS = 12'h004;
    localparam ADDR_HCOUNT = 12'h008;
    localparam ADDR_VCOUNT = 12'h00C;
    localparam ADDR_COLOR  = 12'h010;

    // ---- Programmable registers ----
    reg        reg_display_enable;
    reg        reg_pattern_mode;
    reg [23:0] reg_color;
    reg        frame_flag; // sticky, W1C

    wire hcnt_w, vcnt_w; // unused placeholders removed below
    wire [11:0] hcount, vcount;
    wire hsync_n, vsync_n, video_active, frame_tick;

    vga_timing_gen u_vga_timing (
        .pixel_clk    (pixel_clk),
        .rst_n        (s_axi_aresetn),
        .enable       (reg_display_enable),
        .hcount       (hcount),
        .vcount       (vcount),
        .hsync        (hsync_n),      // active-low from core
        .vsync        (vsync_n),      // active-low from core
        .video_active (video_active),
        .frame_tick   (frame_tick)
    );

    assign hsync_o   = hsync_n;
    assign vsync_o   = vsync_n;
    assign pixel_x_o = hcount;
    assign pixel_y_o = vcount;

    // Pixel color generator (combinational, per current hcount/vcount)
    wire [23:0] gradient_color = {hcount[7:0], vcount[7:0], (hcount[7:0] ^ vcount[7:0])};
    wire [23:0] pixel_color    = reg_pattern_mode ? gradient_color : reg_color;

    assign rgb_r_o = video_active ? pixel_color[23:16] : 8'h00;
    assign rgb_g_o = video_active ? pixel_color[15:8]  : 8'h00;
    assign rgb_b_o = video_active ? pixel_color[7:0]   : 8'h00;

    // frame_flag sticky set (in pixel_clk domain here since pixel_clk==s_axi_aclk
    // per this module's documented assumption)
    // handled in the same always block as bus writes below for W1C semantics.

    // ---- Write channel ----
    reg aw_hs, w_hs;
    reg [11:0] awaddr_latched;
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_awready      <= 1'b0;
            s_axi_wready       <= 1'b0;
            s_axi_bvalid       <= 1'b0;
            s_axi_bresp        <= 2'b00;
            aw_hs              <= 1'b0;
            w_hs               <= 1'b0;
            awaddr_latched     <= 12'h0;
            reg_display_enable <= 1'b0;
            reg_pattern_mode   <= 1'b0;
            reg_color          <= 24'hFFFFFF; // default: white
            frame_flag         <= 1'b0;
        end else begin
            // sticky frame flag set (auto), cleared only by explicit W1C below
            if (frame_tick) frame_flag <= 1'b1;

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
                case (awaddr_latched)
                    ADDR_CTRL: begin
                        if (s_axi_wstrb[0]) begin
                            reg_display_enable <= s_axi_wdata[0];
                            reg_pattern_mode   <= s_axi_wdata[1];
                        end
                    end
                    ADDR_STATUS: begin
                        // W1C: writing 1 to bit3 clears frame_flag
                        if (s_axi_wstrb[0] && s_axi_wdata[3]) frame_flag <= 1'b0;
                    end
                    ADDR_COLOR: begin
                        if (s_axi_wstrb[0]) reg_color[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_color[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_color[23:16] <= s_axi_wdata[23:16];
                    end
                    default: ; // RO / unmapped
                endcase
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
                aw_hs <= 1'b0; w_hs <= 1'b0;
            end
            if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 1'b0;
        end
    end

    // ---- Read channel ----
    reg [11:0] araddr_latched;
    wire [31:0] status_word = {28'h0, frame_flag, video_active, ~vsync_n, ~hsync_n};
    // bit0=hsync active(logical1), bit1=vsync active(logical1), bit2=video_active, bit3=frame_flag

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
                    ADDR_CTRL:   begin s_axi_rdata <= {30'h0, reg_pattern_mode, reg_display_enable}; s_axi_rresp <= 2'b00; end
                    ADDR_STATUS: begin s_axi_rdata <= status_word;      s_axi_rresp <= 2'b00; end
                    ADDR_HCOUNT: begin s_axi_rdata <= {20'h0, hcount};  s_axi_rresp <= 2'b00; end
                    ADDR_VCOUNT: begin s_axi_rdata <= {20'h0, vcount};  s_axi_rresp <= 2'b00; end
                    ADDR_COLOR:  begin s_axi_rdata <= {8'h0, reg_color};s_axi_rresp <= 2'b00; end
                    default:     begin s_axi_rdata <= 32'h0;            s_axi_rresp <= 2'b10; end
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
