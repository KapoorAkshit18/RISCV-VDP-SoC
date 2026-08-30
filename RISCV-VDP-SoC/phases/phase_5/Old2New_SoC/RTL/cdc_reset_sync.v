// =============================================================================
// cdc_reset_sync.v
//
// Standard 2-flop reset synchronizer:
//   - Asynchronous reset assertion
//   - Synchronous reset de-assertion
//
// Used to safely transfer the system reset into a different clock domain,
// such as the VDP pixel-clock domain.
//
// In this SoC, the CPU/native-bus logic and VDP pixel logic may operate in
// different clock domains. Even when both clocks are generated from the same
// source using the Vivado Clocking Wizard, reset de-assertion should be
// synchronized independently in each destination clock domain.
//
// This module is generic CDC infrastructure and is not AXI-specific or
// vendor-specific. It uses plain Verilog-2001 flip-flops and can be
// synthesized for FPGA or ASIC implementations.
// =============================================================================
module cdc_reset_sync (
    input  wire dest_clk,       // Destination clock domain
    input  wire async_rst_n,    // Asynchronous active-low system reset
    output wire sync_rst_n      // Synchronized active-low reset
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