`timescale 1ns/1ps
// =============================================================================
// vdp_native_slave.v
//
// RISC-V / PicoRV32 NATIVE memory-bus VDP peripheral.
//
// This module is NOT AXI4-Lite.
//
// Native bus:
//   mem_valid : request is valid
//   mem_instr : instruction/data indicator (not used by this peripheral)
//   mem_ready : request completed
//   mem_addr  : local peripheral address
//   mem_wdata : write data
//   mem_wstrb : byte write strobes
//   mem_rdata : read data
//
// Address map:
//   0x000 : VDP_CTRL
//           bit 0 = display_enable
//           bit 1 = pattern_mode
//
//   0x004 : VDP_STATUS (RO)
//           bit 0 = hsync active
//           bit 1 = vsync active
//           bit 2 = video active
//           bit 3 = frame flag
//           frame flag is cleared by writing bit3=1 to this address.
//
//   0x008 : VDP_HCOUNT (RO)
//           Current horizontal pixel counter.
//
//   0x00C : VDP_VCOUNT (RO)
//           Current vertical pixel counter.
//
//   0x010 : VDP_COLOR (R/W)
//           RGB888 software register.
//           [23:16] = Red
//           [15:8]  = Green
//           [7:0]   = Blue
//
// Physical VGA output is RGB444:
//           rgb_r_o = color[23:20]
//           rgb_g_o = color[15:12]
//           rgb_b_o = color[7:4]
//
// Clock domains:
//   1. clk      : PicoRV32/native-bus/system-clock domain
//   2. pixel_clk: VGA pixel-clock domain
//
// CDC:
//   - Configuration crosses using a toggle handshake.
//   - Frame event crosses using a toggle.
//   - HSYNC/VSYNC/video_active use synchronizers.
//   - HCOUNT/VCOUNT use Gray-code CDC.
//
// IMPORTANT:
//   pixel_clk is an independent clock.
// =============================================================================

module vdp_native_slave (

    // -------------------------------------------------------------------------
    // PicoRV32 native memory interface
    // -------------------------------------------------------------------------
    input  wire        clk,
    input  wire        resetn,

    input  wire        mem_valid,
    input  wire        mem_instr,
    output reg         mem_ready,

    input  wire [11:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,
    output reg  [31:0] mem_rdata,

    // -------------------------------------------------------------------------
    // Independent VGA pixel clock
    // -------------------------------------------------------------------------
    input  wire        pixel_clk,

    // -------------------------------------------------------------------------
    // VGA outputs
    // -------------------------------------------------------------------------
    output wire        hsync_o,
    output wire        vsync_o,

    output wire [11:0] pixel_x_o,
    output wire [11:0] pixel_y_o,

    // Physical ZedBoard VGA interface: RGB444
    output wire [3:0]  rgb_r_o,
    output wire [3:0]  rgb_g_o,
    output wire [3:0]  rgb_b_o
);

    // =========================================================================
    // Address map
    // =========================================================================

    localparam [11:0] ADDR_CTRL   = 12'h000;
    localparam [11:0] ADDR_STATUS = 12'h004;
    localparam [11:0] ADDR_HCOUNT = 12'h008;
    localparam [11:0] ADDR_VCOUNT = 12'h00C;
    localparam [11:0] ADDR_COLOR  = 12'h010;


    // =========================================================================
    // SYSTEM / NATIVE-BUS CLOCK DOMAIN
    // =========================================================================

    // -------------------------------------------------------------------------
    // Software-visible configuration registers.
    //
    // These registers are ONLY modified in the clk domain.
    // -------------------------------------------------------------------------

    reg        reg_display_enable;
    reg        reg_pattern_mode;
    reg [23:0] reg_color;

    // Configuration update toggle.
    //
    // Every accepted CTRL or COLOR write toggles this bit.
    // The pixel clock domain synchronizes this toggle and detects the change.
    reg cfg_toggle;


    // -------------------------------------------------------------------------
    // Frame flag.
    //
    // This register belongs entirely to the clk domain.
    //
    // It is SET when a frame event arrives from pixel_clk.
    // It is CLEARED by software by writing STATUS bit3 = 1.
    // -------------------------------------------------------------------------

    reg frame_flag;


    // -------------------------------------------------------------------------
    // CDC: frame toggle synchronizer
    // pixel_clk --> clk
    // -------------------------------------------------------------------------

    reg frame_toggle_ff1;
    reg frame_toggle_ff2;
    reg frame_toggle_ff3;

    reg frame_toggle_seen;

    wire frame_event_pulse;

    assign frame_event_pulse =
            frame_toggle_ff3 ^ frame_toggle_seen;


    // -------------------------------------------------------------------------
    // CDC: video status signals
    // pixel_clk --> clk
    //
    // Three-stage synchronizers are used for robustness.
    // -------------------------------------------------------------------------

    reg [2:0] hsync_sync_ff;
    reg [2:0] vsync_sync_ff;
    reg [2:0] video_active_sync_ff;

    wire hsync_active_sync;
    wire vsync_active_sync;
    wire video_active_sync;

    assign hsync_active_sync  = hsync_sync_ff[2];
    assign vsync_active_sync  = vsync_sync_ff[2];
    assign video_active_sync  = video_active_sync_ff[2];


    // -------------------------------------------------------------------------
    // CDC: Gray-coded HCOUNT/VCOUNT
    // pixel_clk --> clk
    // -------------------------------------------------------------------------

    reg [11:0] hcount_gray_ff1;
    reg [11:0] hcount_gray_ff2;

    reg [11:0] vcount_gray_ff1;
    reg [11:0] vcount_gray_ff2;

    wire [11:0] hcount_sync;
    wire [11:0] vcount_sync;


    // -------------------------------------------------------------------------
    // Gray-to-binary conversion.
    // -------------------------------------------------------------------------

    function [11:0] gray2bin;

        input [11:0] gray;

        integer i;
        reg [11:0] bin;

        begin

            bin[11] = gray[11];

            for (i = 10; i >= 0; i = i - 1)
                bin[i] = bin[i+1] ^ gray[i];

            gray2bin = bin;

        end

    endfunction


    assign hcount_sync = gray2bin(hcount_gray_ff2);
    assign vcount_sync = gray2bin(vcount_gray_ff2);


    // -------------------------------------------------------------------------
    // Status register.
    //
    // bit 0 = HSYNC active
    // bit 1 = VSYNC active
    // bit 2 = video active
    // bit 3 = frame event occurred
    // -------------------------------------------------------------------------

    wire [31:0] status_word;

    assign status_word = {
        28'h0,
        frame_flag,
        video_active_sync,
        vsync_active_sync,
        hsync_active_sync
    };


    // =========================================================================
    // NATIVE BUS TRANSACTION CONTROL
    // =========================================================================
    //
    // The peripheral uses a simple one-cycle response.
    //
    // When mem_valid is seen:
    //   - write: perform write and assert mem_ready
    //   - read : generate read data and assert mem_ready
    //
    // mem_ready is registered, therefore it is NOT combinational with
    // mem_valid.
    // =========================================================================

    always @(posedge clk or negedge resetn) begin

        if (!resetn) begin

            mem_ready <= 1'b0;
            mem_rdata <= 32'h0000_0000;

            reg_display_enable <= 1'b0;
            reg_pattern_mode   <= 1'b0;
            reg_color          <= 24'hFFFFFF;

            cfg_toggle <= 1'b0;

            frame_flag        <= 1'b0;
            frame_toggle_seen <= 1'b0;

        end
        else begin

            // Default: no response.
            mem_ready <= 1'b0;


            // -----------------------------------------------------------------
            // Receive frame event from pixel clock domain.
            // -----------------------------------------------------------------

            if (frame_event_pulse) begin

                frame_flag        <= 1'b1;
                frame_toggle_seen <= frame_toggle_ff3;

            end


            // -----------------------------------------------------------------
            // Native memory transaction.
            // -----------------------------------------------------------------

            if (mem_valid) begin

                // -------------------------------------------------------------
                // WRITE
                // -------------------------------------------------------------

                if (|mem_wstrb) begin

                    case (mem_addr)

                        // -----------------------------------------------------
                        // VDP_CTRL
                        //
                        // bit0 = display enable
                        // bit1 = pattern mode
                        // -----------------------------------------------------

                        ADDR_CTRL: begin

                            if (mem_wstrb[0]) begin

                                reg_display_enable <= mem_wdata[0];
                                reg_pattern_mode   <= mem_wdata[1];

                                // Notify pixel clock domain.
                                cfg_toggle <= ~cfg_toggle;

                            end

                        end


                        // -----------------------------------------------------
                        // VDP_STATUS
                        //
                        // bit3 = W1C frame flag
                        // -----------------------------------------------------

                        ADDR_STATUS: begin

                            if (mem_wstrb[0] &&
                                mem_wdata[3]) begin

                                frame_flag <= 1'b0;

                            end

                        end


                        // -----------------------------------------------------
                        // VDP_COLOR
                        //
                        // Byte-wise write support.
                        // -----------------------------------------------------

                        ADDR_COLOR: begin

                            if (mem_wstrb[0])
                                reg_color[7:0] <= mem_wdata[7:0];

                            if (mem_wstrb[1])
                                reg_color[15:8] <= mem_wdata[15:8];

                            if (mem_wstrb[2])
                                reg_color[23:16] <= mem_wdata[23:16];

                            // Notify pixel clock domain.
                            cfg_toggle <= ~cfg_toggle;

                        end


                        default: begin
                            // Unmapped writes are ignored.
                        end

                    endcase

                end


                // -------------------------------------------------------------
                // READ
                //
                // mem_wstrb == 0 indicates a read transaction.
                // -------------------------------------------------------------

                else begin

                    case (mem_addr)

                        ADDR_CTRL: begin

                            mem_rdata <= {
                                30'h0,
                                reg_pattern_mode,
                                reg_display_enable
                            };

                        end


                        ADDR_STATUS: begin

                            mem_rdata <= status_word;

                        end


                        ADDR_HCOUNT: begin

                            mem_rdata <= {
                                20'h0,
                                hcount_sync
                            };

                        end


                        ADDR_VCOUNT: begin

                            mem_rdata <= {
                                20'h0,
                                vcount_sync
                            };

                        end


                        ADDR_COLOR: begin

                            mem_rdata <= {
                                8'h00,
                                reg_color
                            };

                        end


                        default: begin

                            // Native bus has no AXI SLVERR response.
                            // Unmapped reads return zero.

                            mem_rdata <= 32'h0000_0000;

                        end

                    endcase

                end


                // Complete transaction.
                mem_ready <= 1'b1;

            end

        end

    end


    // =========================================================================
    // CDC: PIXEL CLOCK DOMAIN
    // =========================================================================

    // -------------------------------------------------------------------------
    // Configuration toggle synchronizer.
    //
    // clk --> pixel_clk
    // -------------------------------------------------------------------------

    reg cfg_toggle_ff1;
    reg cfg_toggle_ff2;
    reg cfg_toggle_ff3;

    reg cfg_toggle_seen;


    wire cfg_update_pulse;

    assign cfg_update_pulse =
            cfg_toggle_ff3 ^ cfg_toggle_seen;


    // -------------------------------------------------------------------------
    // Pixel-domain copies of software configuration.
    // -------------------------------------------------------------------------

    reg        display_enable_pclk;
    reg        pattern_mode_pclk;
    reg [23:0] color_pclk;


    // -------------------------------------------------------------------------
    // Pixel-domain configuration synchronizer.
    // -------------------------------------------------------------------------

    always @(posedge pixel_clk or negedge resetn) begin

        if (!resetn) begin

            cfg_toggle_ff1 <= 1'b0;
            cfg_toggle_ff2 <= 1'b0;
            cfg_toggle_ff3 <= 1'b0;

            cfg_toggle_seen <= 1'b0;

            display_enable_pclk <= 1'b0;
            pattern_mode_pclk   <= 1'b0;

            color_pclk <= 24'hFFFFFF;

        end
        else begin

            cfg_toggle_ff1 <= cfg_toggle;
            cfg_toggle_ff2 <= cfg_toggle_ff1;
            cfg_toggle_ff3 <= cfg_toggle_ff2;


            if (cfg_update_pulse) begin

                display_enable_pclk <= reg_display_enable;
                pattern_mode_pclk   <= reg_pattern_mode;
                color_pclk          <= reg_color;

                cfg_toggle_seen <= cfg_toggle_ff3;

            end

        end

    end


    // =========================================================================
    // VGA TIMING GENERATOR
    // =========================================================================

    wire [11:0] hcount;
    wire [11:0] vcount;

    wire hsync_n;
    wire vsync_n;
    wire video_active;
    wire frame_tick;


    vga_timing_gen u_vga_timing (

        .pixel_clk    (pixel_clk),
        .rst_n        (resetn),

        .enable       (display_enable_pclk),

        .hcount       (hcount),
        .vcount       (vcount),

        .hsync        (hsync_n),
        .vsync        (vsync_n),

        .video_active (video_active),
        .frame_tick   (frame_tick)

    );


    // =========================================================================
    // FRAME EVENT CDC
    // =========================================================================

    // Toggle every frame in pixel clock domain.

    reg frame_toggle_pclk;

    always @(posedge pixel_clk or negedge resetn) begin

        if (!resetn)

            frame_toggle_pclk <= 1'b0;

        else if (frame_tick)

            frame_toggle_pclk <= ~frame_toggle_pclk;

    end


    // Synchronize frame toggle into clk domain.

    always @(posedge clk or negedge resetn) begin

        if (!resetn) begin

            frame_toggle_ff1 <= 1'b0;
            frame_toggle_ff2 <= 1'b0;
            frame_toggle_ff3 <= 1'b0;

        end
        else begin

            frame_toggle_ff1 <= frame_toggle_pclk;
            frame_toggle_ff2 <= frame_toggle_ff1;
            frame_toggle_ff3 <= frame_toggle_ff2;

        end

    end


    // =========================================================================
    // STATUS CDC
    // =========================================================================

    always @(posedge clk or negedge resetn) begin

        if (!resetn) begin

            hsync_sync_ff       <= 3'b000;
            vsync_sync_ff       <= 3'b000;
            video_active_sync_ff <= 3'b000;

        end
        else begin

            // hsync/vsync are active-low at the VGA pins.
            // Convert them to active-high status bits.

            hsync_sync_ff <= {
                hsync_sync_ff[1:0],
                ~hsync_n
            };

            vsync_sync_ff <= {
                vsync_sync_ff[1:0],
                ~vsync_n
            };

            video_active_sync_ff <= {
                video_active_sync_ff[1:0],
                video_active
            };

        end

    end


    // =========================================================================
    // HCOUNT / VCOUNT CDC
    // =========================================================================

    function [11:0] bin2gray;

        input [11:0] bin;

        begin

            bin2gray = bin ^ (bin >> 1);

        end

    endfunction


    wire [11:0] hcount_gray_pclk;
    wire [11:0] vcount_gray_pclk;


    assign hcount_gray_pclk = bin2gray(hcount);
    assign vcount_gray_pclk = bin2gray(vcount);


    always @(posedge clk or negedge resetn) begin

        if (!resetn) begin

            hcount_gray_ff1 <= 12'h000;
            hcount_gray_ff2 <= 12'h000;

            vcount_gray_ff1 <= 12'h000;
            vcount_gray_ff2 <= 12'h000;

        end
        else begin

            hcount_gray_ff1 <= hcount_gray_pclk;
            hcount_gray_ff2 <= hcount_gray_ff1;

            vcount_gray_ff1 <= vcount_gray_pclk;
            vcount_gray_ff2 <= vcount_gray_ff1;

        end

    end


    // =========================================================================
    // PIXEL GENERATION
    // =========================================================================

    // Gradient pattern.
    //
    // This is intentionally generated entirely inside pixel_clk domain.
    // Therefore no CDC is involved in the pixel color calculation.

    wire [23:0] gradient_color;

    assign gradient_color = {
        hcount[7:0],
        vcount[7:0],
        hcount[7:0] ^ vcount[7:0]
    };


    wire [23:0] pixel_color;

    assign pixel_color =
            pattern_mode_pclk ?
            gradient_color :
            color_pclk;


    // =========================================================================
    // VGA OUTPUTS
    // =========================================================================

    // VGA timing outputs are active-low.

    assign hsync_o = hsync_n;
    assign vsync_o = vsync_n;


    // Expose current pixel coordinates.

    assign pixel_x_o = hcount;
    assign pixel_y_o = vcount;


    // -------------------------------------------------------------------------
    // RGB444 output.
    //
    // Software writes RGB888:
    //
    //     R = color[23:16]
    //     G = color[15:8]
    //     B = color[7:0]
    //
    // ZedBoard physical interface is RGB444:
    //
    //     R = color[23:20]
    //     G = color[15:12]
    //     B = color[7:4]
    //
    // During blanking, RGB outputs are forced to zero.
    // -------------------------------------------------------------------------

    assign rgb_r_o =
            video_active ?
            pixel_color[23:20] :
            4'h0;

    assign rgb_g_o =
            video_active ?
            pixel_color[15:12] :
            4'h0;

    assign rgb_b_o =
            video_active ?
            pixel_color[7:4] :
            4'h0;


endmodule