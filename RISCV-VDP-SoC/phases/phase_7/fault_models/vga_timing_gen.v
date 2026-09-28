// =============================================================================
// vga_timing_gen.v
// Standard 640x480 @ 60Hz VGA timing generator, driven from a 25MHz pixel clock
// (pixel clock generation/PLL is out of scope here -- assumed provided upstream,
// e.g. by LLM-3's FPGA clocking wizard / integration top level).
//
// Timing constants (industry-standard 640x480@60Hz, 25.175MHz nominal):
//   Horizontal: 640 visible + 16 front porch + 96 sync + 48 back porch = 800 total
//   Vertical:    480 visible + 10 front porch +  2 sync + 33 back porch = 525 total
//   HSYNC, VSYNC are ACTIVE LOW per the VESA spec for this mode.
//
// This module has NO AXI/bus interface and NO address decoder -- it is a pure
// free-running timing engine. vdp_axi_slave.v instantiates this and layers the
// programmable register interface + pixel-color logic on top.
// =============================================================================
module vga_timing_gen #(
    parameter H_VISIBLE     = 640,
    parameter H_FRONT_PORCH = 16,
    parameter H_SYNC_PULSE  = 96,
    parameter H_BACK_PORCH  = 48,
    parameter V_VISIBLE     = 480,
    parameter V_FRONT_PORCH = 10,
    parameter V_SYNC_PULSE  = 2,
    parameter V_BACK_PORCH  = 33
)(
    input  wire        pixel_clk,
    input  wire         rst_n,
    input  wire        enable,          // 0 = hold counters at 0, sync/blank forced idle

    output wire [11:0] hcount,          // 0 .. H_TOTAL-1
    output wire [11:0] vcount,          // 0 .. V_TOTAL-1
    output wire         hsync,
    output wire         vsync,
    //output reg         hsync,           // active low
    //output reg         vsync,           // active low
    output wire        video_active,    // 1 during visible area (both H and V)
    output wire        frame_tick       // 1-cycle pulse at start of each frame (h=0,v=0)
);

    localparam H_TOTAL = H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH; // 800
    localparam V_TOTAL = V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH; // 525

    localparam H_SYNC_START = H_VISIBLE + H_FRONT_PORCH;                  // 656
    localparam H_SYNC_END   = H_SYNC_START + H_SYNC_PULSE;                // 752
    localparam V_SYNC_START = V_VISIBLE + V_FRONT_PORCH;                  // 490
    localparam V_SYNC_END   = V_SYNC_START + V_SYNC_PULSE;                // 492

    reg [11:0] h_cnt;
    reg [11:0] v_cnt;

    wire h_end = (h_cnt == H_TOTAL - 1);
    wire v_end = (v_cnt == V_TOTAL - 1);

    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 12'd0;
            v_cnt <= 12'd0;
        end else if (!enable) begin
            h_cnt <= 12'd0;
            v_cnt <= 12'd0;
        end else begin
            if (h_end) begin
                h_cnt <= 12'd0;
                v_cnt <= v_end ? 12'd0 : v_cnt + 12'd1;
            end else begin
                h_cnt <= h_cnt + 12'd1;
            end
        end
    end

    // always @(posedge pixel_clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         hsync <= 1'b1; // idle (inactive) level
    //         vsync <= 1'b1;
    //     end else begin
    //         hsync <= ~(h_cnt >= H_SYNC_START && h_cnt < H_SYNC_END);
    //         vsync <= ~(v_cnt >= V_SYNC_START && v_cnt < V_SYNC_END);
    //     end
    // end

    // -----------------------------------------------------------------------------
// VGA sync generation
//
// HSYNC and VSYNC are combinational functions of the CURRENT counters.
// This keeps the sync outputs aligned with hcount/vcount.
//
// 640x480 timing:
//   HSYNC active: hcount = 656 .. 751
//   VSYNC active: vcount = 490 .. 491
//
// Both sync signals are active-low.
// -----------------------------------------------------------------------------
assign hsync = enable ?
               !((h_cnt >= H_SYNC_START) && (h_cnt < H_SYNC_END)) :
               1'b1;

assign vsync = enable ?
               !((v_cnt >= V_SYNC_START) && (v_cnt < V_SYNC_END)) :
               1'b1;

    assign hcount       = h_cnt;
    assign vcount       = v_cnt;
    assign video_active = (h_cnt < H_VISIBLE) && (v_cnt < V_VISIBLE);
    assign frame_tick   = (h_cnt == 12'd0) && (v_cnt == 12'd0);

endmodule
