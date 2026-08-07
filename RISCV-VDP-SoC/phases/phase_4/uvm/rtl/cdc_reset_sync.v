// =============================================================================
// cdc_reset_sync.v
// Standard 2-flop reset synchronizer: asynchronous assert, synchronous
// de-assert. Used to safely bring the s_axi_aresetn reset (asserted/released
// in the AXI/system-clock domain) into any other clock domain (e.g. the VDP
// pixel_clk domain) without introducing a recovery/removal timing violation
// or a reset de-assertion race.
//
// This is generic CDC infrastructure, not vendor-specific -- plain Verilog-2001
// flip-flops, synthesizes on any FPGA/ASIC target.
// =============================================================================
module cdc_reset_sync (
    input  wire dest_clk,       // clock domain the reset is being synchronized into
    input  wire async_rst_n,    // asynchronous active-low reset source
    output wire sync_rst_n      // synchronized active-low reset, safe to use in dest_clk domain
);

    reg rst_ff1, rst_ff2;

    always @(posedge dest_clk or negedge async_rst_n) begin
        if (!async_rst_n) begin
            rst_ff1 <= 1'b0;
            rst_ff2 <= 1'b0;
        end else begin
            rst_ff1 <= 1'b1;
            rst_ff2 <= rst_ff1;
        end
    end

    assign sync_rst_n = rst_ff2;

endmodule
