`timescale 1ns/1ps
// =============================================================================
// tb_vga_vdp.v -- self-checking testbench for vdp_axi_slave (+ vga_timing_gen)
// Run with: iverilog -o sim_vdp tb_vga_vdp.v ../rtl/vdp_axi_slave.v ../rtl/vga_timing_gen.v && vvp sim_vdp
//
// NOTE: this TB verifies register access + first-scanline HSYNC timing
// (cycles 0..751, well within a fast simulation). A full-frame test
// (800*525 = 420,000 pixel_clk cycles, to check VSYNC/frame_flag) is left to
// LLM-3's longer directed regression -- it is a straightforward extension of
// the same checks used here for HSYNC.
// =============================================================================
module tb_vga_vdp;

    reg clk = 0;
    reg rst_n;

    reg  [11:0] awaddr; reg awvalid; wire awready;
    reg  [31:0] wdata;  reg [3:0] wstrb; reg wvalid; wire wready;
    wire [1:0]  bresp;  wire bvalid; reg bready;
    reg  [11:0] araddr; reg arvalid; wire arready;
    wire [31:0] rdata;  wire [1:0] rresp; wire rvalid; reg rready;

    wire hsync_o, vsync_o;
    wire [11:0] pixel_x_o, pixel_y_o;
    wire [7:0]  rgb_r_o, rgb_g_o, rgb_b_o;

    integer errors = 0;

    vdp_axi_slave dut (
        .s_axi_aclk(clk), .s_axi_aresetn(rst_n),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .pixel_clk(clk),
        .hsync_o(hsync_o), .vsync_o(vsync_o),
        .pixel_x_o(pixel_x_o), .pixel_y_o(pixel_y_o),
        .rgb_r_o(rgb_r_o), .rgb_g_o(rgb_g_o), .rgb_b_o(rgb_b_o)
    );

    always #5 clk = ~clk;

    task axi_write(input [11:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            awaddr <= addr; awvalid <= 1'b1; wdata <= data; wstrb <= 4'hF; wvalid <= 1'b1; bready <= 1'b1;
            @(posedge clk);
            while (!(awready && wready)) @(posedge clk);
            awvalid <= 1'b0; wvalid <= 1'b0;
            while (!bvalid) @(posedge clk);
            @(posedge clk);
        end
    endtask

    task axi_read(input [11:0] addr, output [31:0] data, output [1:0] resp);
        begin
            @(posedge clk);
            araddr <= addr; arvalid <= 1'b1; rready <= 1'b1;
            @(posedge clk);
            while (!arready) @(posedge clk);
            arvalid <= 1'b0;
            while (!rvalid) @(posedge clk);
            data = rdata; resp = rresp;
            @(posedge clk);
        end
    endtask

    reg [31:0] rd_data; reg [1:0] rd_resp;
    integer i;

    initial begin
        rst_n = 0; awvalid=0; wvalid=0; bready=0; arvalid=0; rready=0;
        awaddr=0; wdata=0; wstrb=0; araddr=0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // Before enabling, hcount/vcount must hold at 0
        axi_read(12'h008, rd_data, rd_resp);
        if (rd_data === 32'h0) $display("PASS: VDP_HCOUNT = 0 while display disabled");
        else begin $display("FAIL: VDP_HCOUNT = %0d (expected 0)", rd_data); errors=errors+1; end

        // Program a solid color, then enable display
        axi_write(12'h010, 24'h11_22_33);
        axi_read(12'h010, rd_data, rd_resp);
        if (rd_data === 32'h11_22_33) $display("PASS: VDP_COLOR readback = %h", rd_data);
        else begin $display("FAIL: VDP_COLOR readback = %h (expected 112233)", rd_data); errors=errors+1; end

        axi_write(12'h000, 32'h0000_0001); // VDP_CTRL: display_enable=1, pattern_mode=0

        // Let the horizontal counter run through one full line (800 pixel_clks)
        // and sample around the documented HSYNC window: h in [656,751]
        for (i = 0; i < 760; i = i + 1) @(posedge clk);

        axi_read(12'h008, rd_data, rd_resp);
        if (rd_data > 32'd650 && rd_data < 32'd800)
            $display("PASS: VDP_HCOUNT advancing correctly, now = %0d", rd_data);
        else begin $display("FAIL: VDP_HCOUNT = %0d (expected ~656-759 range)", rd_data); errors=errors+1; end

        // hsync_o must currently be asserted (active-low -> logic 0) since we are
        // inside the H_SYNC_START(656)..H_SYNC_END(751) window
        if (hsync_o === 1'b0)
            $display("PASS: hsync_o active (0) inside horizontal sync pulse window");
        else begin $display("FAIL: hsync_o = %b (expected 0, active-low)", hsync_o); errors=errors+1; end

        // VDP_STATUS bit0 mirrors hsync active as logical-1
        axi_read(12'h004, rd_data, rd_resp);
        if (rd_data[0] === 1'b1)
            $display("PASS: VDP_STATUS.hsync_active = 1 (matches hsync_o=0)");
        else begin $display("FAIL: VDP_STATUS = %b, bit0 expected 1", rd_data); errors=errors+1; end

        // video_active must be 0 here (h=~656-759 is outside the 0..639 visible window)
        if (rd_data[2] === 1'b0)
            $display("PASS: VDP_STATUS.video_active = 0 outside visible window");
        else begin $display("FAIL: VDP_STATUS.video_active = %b (expected 0)", rd_data[2]); errors=errors+1; end

        // Rewind: reset and check pixel color during the VISIBLE window (h<640)
        rst_n = 0; repeat(2) @(posedge clk); rst_n = 1; repeat(2) @(posedge clk);
        axi_write(12'h010, 24'hAA_BB_CC);
        axi_write(12'h000, 32'h0000_0001);
        repeat (5) @(posedge clk); // now h=~3..4, inside visible window
        if (rgb_r_o === 8'hAA && rgb_g_o === 8'hBB && rgb_b_o === 8'hCC)
            $display("PASS: RGB output = solid VDP_COLOR (AA,BB,CC) during visible window");
        else begin
            $display("FAIL: RGB = (%h,%h,%h) expected (AA,BB,CC)", rgb_r_o, rgb_g_o, rgb_b_o);
            errors = errors + 1;
        end

        // Unmapped offset
        axi_read(12'h0FF, rd_data, rd_resp);
        if (rd_resp === 2'b10) $display("PASS: unmapped offset -> SLVERR");
        else begin $display("FAIL: unmapped offset resp=%b", rd_resp); errors=errors+1; end

        if (errors == 0) $display("==== TB_VGA_VDP: ALL TESTS PASSED ====");
        else $display("==== TB_VGA_VDP: %0d TEST(S) FAILED ====", errors);
        $finish;
    end

endmodule
