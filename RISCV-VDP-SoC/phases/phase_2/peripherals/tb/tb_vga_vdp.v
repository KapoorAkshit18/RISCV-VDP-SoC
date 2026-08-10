`timescale 1ns/1ps

// =============================================================================
// tb_vga_vdp_native.v
//
// Self-checking testbench for:
//
//     vdp_native_slave
//     vga_timing_gen
//
// IMPORTANT:
//   This testbench uses the PicoRV32 NATIVE memory interface.
//   There is NO AXI4-Lite interface here.
//
// Native bus:
//     mem_valid
//     mem_ready
//     mem_addr
//     mem_wdata
//     mem_wstrb
//     mem_rdata
//
// Clock domains:
//
//     clk_axi   = 100 MHz system/native-bus clock
//     clk_pixel = 25 MHz VGA pixel clock
//
// The two clocks are intentionally asynchronous.
//
// Compile:
//
//   iverilog -g2012 -o sim_vdp \
//       tb_vga_vdp_native.v \
//       ../rtl/vdp_native_slave.v \
//       ../rtl/vga_timing_gen.v
//
// Run:
//
//   vvp sim_vdp
// =============================================================================

module tb_vga_vdp_native;

    // =========================================================================
    // CLOCKS
    // =========================================================================

    reg clk_axi   = 1'b0;
    reg clk_pixel = 1'b0;

    // 100 MHz system clock
    always #5 clk_axi = ~clk_axi;

    // 25 MHz pixel clock.
    //
    // The initial #13 creates a phase difference from clk_axi.
    initial begin
        clk_pixel = 1'b0;
        #13;

        forever
            #20 clk_pixel = ~clk_pixel;
    end


    // =========================================================================
    // RESET
    // =========================================================================

    reg resetn;


    // =========================================================================
    // NATIVE PICO RV32 BUS
    // =========================================================================

    reg         mem_valid;
    reg         mem_instr;

    wire        mem_ready;

    reg  [11:0] mem_addr;
    reg  [31:0] mem_wdata;
    reg  [3:0]  mem_wstrb;

    wire [31:0] mem_rdata;


    // =========================================================================
    // VGA OUTPUTS
    // =========================================================================

    wire       hsync_o;
    wire       vsync_o;

    wire [11:0] pixel_x_o;
    wire [11:0] pixel_y_o;

    wire [3:0] rgb_r_o;
    wire [3:0] rgb_g_o;
    wire [3:0] rgb_b_o;


    // =========================================================================
    // DUT
    // =========================================================================

    vdp_native_slave dut (

        .clk       (clk_axi),
        .resetn    (resetn),

        .mem_valid (mem_valid),
        .mem_instr (mem_instr),
        .mem_ready (mem_ready),

        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),
        .mem_rdata (mem_rdata),

        .pixel_clk (clk_pixel),

        .hsync_o   (hsync_o),
        .vsync_o   (vsync_o),

        .pixel_x_o (pixel_x_o),
        .pixel_y_o (pixel_y_o),

        .rgb_r_o   (rgb_r_o),
        .rgb_g_o   (rgb_g_o),
        .rgb_b_o   (rgb_b_o)
    );


    // =========================================================================
    // TEST CONTROL
    // =========================================================================

    integer errors = 0;

    reg [31:0] rd_data;


    // =========================================================================
    // NATIVE WRITE TASK
    // =========================================================================
    //
    // The master holds mem_valid and all request information until mem_ready.
    //
    // This models the PicoRV32 native memory protocol.
    // =========================================================================

    task native_write;

        input [11:0] addr;
        input [31:0] data;
        input [3:0]  strb;

        begin

            @(posedge clk_axi);

            mem_addr  <= addr;
            mem_wdata <= data;
            mem_wstrb <= strb;
            mem_instr <= 1'b0;

            mem_valid <= 1'b1;


            // Keep request stable until slave acknowledges it.

            while (!mem_ready)
                @(posedge clk_axi);


            // Transaction completed.

            @(posedge clk_axi);

            mem_valid <= 1'b0;
            mem_wstrb <= 4'h0;
            mem_addr  <= 12'h000;
            mem_wdata <= 32'h0000_0000;


            @(posedge clk_axi);

        end

    endtask


    // =========================================================================
    // NATIVE READ TASK
    // =========================================================================

    task native_read;

        input  [11:0] addr;
        output [31:0] data;

        begin

            @(posedge clk_axi);

            mem_addr  <= addr;
            mem_wdata <= 32'h0000_0000;
            mem_wstrb <= 4'h0;
            mem_instr <= 1'b0;

            mem_valid <= 1'b1;


            // Wait for native-bus completion.

            while (!mem_ready)
                @(posedge clk_axi);


            // Capture read data.

            data = mem_rdata;


            // Release request.

            @(posedge clk_axi);

            mem_valid <= 1'b0;
            mem_addr  <= 12'h000;


            @(posedge clk_axi);

        end

    endtask


    // =========================================================================
    // WAIT FOR SPECIFIC PIXEL COORDINATE
    // =========================================================================
    //
    // Instead of assuming:
    //
    //     "after 700 pixel clocks we must be inside HSYNC"
    //
    // we explicitly wait until the VGA timing generator reports the required
    // horizontal coordinate.
    //
    // This makes the test independent of the exact point where the test began.
    // =========================================================================

    task wait_for_hcount;

        input [11:0] target;

        integer timeout;

        begin

            timeout = 0;

            while (pixel_x_o != target) begin

                @(posedge clk_pixel);

                timeout = timeout + 1;

                if (timeout > 2000) begin

                    $display(
                        "FAIL: timeout waiting for HCOUNT=%0d, current=%0d",
                        target,
                        pixel_x_o
                    );

                    errors = errors + 1;

                    disable wait_for_hcount;

                end

            end

        end

    endtask


    // =========================================================================
    // MAIN TEST
    // =========================================================================

    initial begin

        // ---------------------------------------------------------------------
        // Initial values
        // ---------------------------------------------------------------------

        resetn = 1'b0;

        mem_valid = 1'b0;
        mem_instr = 1'b0;

        mem_addr  = 12'h000;
        mem_wdata = 32'h0000_0000;
        mem_wstrb = 4'h0;


        // ---------------------------------------------------------------------
        // Reset
        // ---------------------------------------------------------------------

        repeat (6)
            @(posedge clk_axi);

        resetn = 1'b1;


        // Give both clock domains time to leave reset.

        repeat (6)
            @(posedge clk_axi);


        $display("");
        $display("============================================================");
        $display(" VDP NATIVE-BUS TEST");
        $display("============================================================");
        $display("");


        // =====================================================================
        // TEST 1
        // VDP_COLOR WRITE
        // =====================================================================

        $display("TEST 1: VDP_COLOR write");

        native_write(
            12'h010,
            32'h00A5_B6C7,
            4'b0111
        );


        // =====================================================================
        // TEST 2
        // VDP_COLOR READBACK
        // =====================================================================

        $display("TEST 2: VDP_COLOR readback");

        native_read(
            12'h010,
            rd_data
        );


        if (rd_data === 32'h00A5_B6C7) begin

            $display(
                "PASS: VDP_COLOR readback = %h",
                rd_data
            );

        end
        else begin

            $display(
                "FAIL: VDP_COLOR readback = %h, expected 00A5B6C7",
                rd_data
            );

            errors = errors + 1;

        end


        // =====================================================================
        // TEST 3
        // ENABLE DISPLAY
        // =====================================================================

        $display("TEST 3: Enable VDP display");

        native_write(
            12'h000,
            32'h0000_0001,
            4'hF
        );


        // ---------------------------------------------------------------------
        // Wait for configuration CDC.
        //
        // The configuration does NOT immediately appear in pixel_clk domain.
        // It passes through the toggle synchronizer.
        // ---------------------------------------------------------------------

        repeat (10)
            @(posedge clk_pixel);


        // =====================================================================
        // TEST 4
        // VDP_CTRL READBACK
        // =====================================================================

        $display("TEST 4: VDP_CTRL readback");

        native_read(
            12'h000,
            rd_data
        );


        if (rd_data === 32'h0000_0001) begin

            $display(
                "PASS: VDP_CTRL = %h (display enabled)",
                rd_data
            );

        end
        else begin

            $display(
                "FAIL: VDP_CTRL = %h, expected 00000001",
                rd_data
            );

            errors = errors + 1;

        end


        // =====================================================================
        // TEST 5
        // WAIT FOR VIDEO AC // =====================================================================
        //
        // We don't assume a fixed number of cycles.
        // Wait until the actual timing generator enters the active display area.
        // =====================================================================

        $display("TEST 5: Wait for active video");

        while (!dut.video_active)
            @(posedge clk_pixel);


        $display(
            "PASS: video_active asserted at X=%0d Y=%0d",
            pixel_x_o,
            pixel_y_o
        );


        // =====================================================================
        // TEST 6
        // RGB444
        // =====================================================================
        //
        // Color:
        //
        //     RGB888 = A5 B6 C7
        //
        // Physical RGB444:
        //
        //     R = A
        //     G = B
        //     B = C
        //
        // We check only while video_active is high.
        // =====================================================================

        $display("TEST 6: RGB444 output");


        if ((rgb_r_o === 4'hA) &&
            (rgb_g_o === 4'hB) &&
            (rgb_b_o === 4'hC)) begin

            $display(
                "PASS: RGB444 = (%h,%h,%h)",
                rgb_r_o,
                rgb_g_o,
                rgb_b_o
            );

        end
        else begin

            $display(TIVE
       
                "FAIL: RGB444 = (%h,%h,%h), expected (A,B,C)",
                rgb_r_o,
                rgb_g_o,
                rgb_b_o
            );

            errors = errors + 1;

        end


        // =====================================================================
        // TEST 7
        // HCOUNT
        // =====================================================================

        $display("TEST 7: HCOUNT");

        native_read(
            12'h008,
            rd_data
        );


        if (rd_data < 32'd800) begin

            $display(
                "PASS: VDP_HCOUNT = %0d",
                rd_data
            );

        end
        else begin

            $display(
                "FAIL: VDP_HCOUNT = %0d, expected < 800",
                rd_data
            );

            errors = errors + 1;

        end


        // =====================================================================
        // TEST 8
        // VCOUNT
        // =====================================================================

        $display("TEST 8: VCOUNT");

        native_read(
            12'h00C,
            rd_data
        );


        if (rd_data < 32'd525) begin

            $display(
                "PASS: VDP_VCOUNT = %0d",
                rd_data
            );

        end
        else begin

            $display(
                "FAIL: VDP_VCOUNT = %0d, expected < 525",
                rd_data
            );

            errors = errors + 1;

        end


        // =====================================================================
        // TEST 9
        // HSYNC
        // =====================================================================
        //
        // Standard 640x480 timing:
        //
        //   visible:      0 - 639
        //   front porch: 640 - 655
        //   sync pulse:  656 - 751
        //   back porch:  752 - 799
        //
        // HSYNC is active-low.
        //
        // Therefore when:
        //
        //     HCOUNT = 656
        //
        // HSYNC should become 0.
        // =====================================================================

        $display("TEST 9: HSYNC timing");


        wait_for_hcount(12'd656);


        // Allow combinational output to settle.

        #1;


        if (hsync_o === 1'b0) begin

            $display(
                "PASS: HSYNC active-low at HCOUNT=%0d",
                pixel_x_o
            );

        end
        else begin

            $display(
                "FAIL: HSYNC=%b at HCOUNT=%0d, expected 0",
                hsync_o,
                pixel_x_o
            );

            errors = errors + 1;

        end


        // =====================================================================
        // TEST 10
        // VDP_STATUS HSYNC CDC
        // =====================================================================
        //
        // HSYNC crosses from pixel_clk to clk_axi through a 3-stage
        // synchronizer.
        //
        // Therefore we deliberately wait several system-clock cycles before
        // reading STATUS.
        // =====================================================================

        repeat (5)
            @(posedge clk_axi);


        native_read(
            12'h004,
            rd_data
        );


        if (rd_data[0] === 1'b1) begin

            $display(
                "PASS: VDP_STATUS.hsync_active = 1"
            );

        end
        else begin

            $display(
                "FAIL: VDP_STATUS.hsync_active = %b, expected 1",
                rd_data[0]
            );

            errors = errors + 1;

        end


        // =====================================================================
        // TEST 11
        // UNMAPPED READ
        // =====================================================================

        $display("TEST 11: Unmapped address");

        native_read(
            12'h0FF,
            rd_data
        );


        if (rd_data === 32'h0000_0000) begin

            $display(
                "PASS: unmapped offset 0x0FF reads 0"
            );

        end
        else begin

            $display(
                "FAIL: unmapped read returned %h",
                rd_data
            );

            errors = errors + 1;

        end


        // =====================================================================
        // FINAL RESULT
        // =====================================================================

        $display("");
        $display("============================================================");

        if (errors == 0) begin

            $display(
                "==== TB_VGA_VDP_NATIVE: ALL TESTS PASSED ===="
            );

        end
        else begin

            $display(
                "==== TB_VGA_VDP_NATIVE: %0d TEST(S) FAILED ====",
                errors
            );

        end

        $display("============================================================");
        $display("");


        //$finish;

    end

endmodule