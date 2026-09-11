`timescale 1ns / 1ps
`ifndef TPU_AXIS_TOP_V
`define TPU_AXIS_TOP_V

//==============================================================================
// Module      : tpu_axis_top
// Project     : RISCV-VDP-SoC
//
// Description :
//   Top-level TPU integration wrapper.
//
//   This module structurally connects the native MMIO register bank,
//   AXI4-Stream packet generator, existing axis_nn accelerator wrapper,
//   and result capture logic.
//
// Hierarchy:
//
//       Native SoC bus
//              |
//              v
//       nn_axi_wrapper
//              |
//              v
//       nn_axis_master
//              |
//              v
//          axis_nn
//              |
//              v
//       result capture
//
// IMPORTANT:
//   axis_nn already contains nn nn_0.
//   No separate nn instance is created here.
//
//==============================================================================

module tpu_axis_top #(
    parameter BASE_ADDR = 32'h0001_4000
)(
    input wire         clk,
    input wire         rst_n,

    //--------------------------------------------------------------------------
    // Native NN slave interface from soc_mem_interconnect
    //--------------------------------------------------------------------------
    input  wire        nn_valid,
    input  wire        nn_write,
    input  wire [11:0] nn_addr,
    input  wire [31:0] nn_wdata,
    input  wire [3:0]  nn_strb,

    output wire        nn_ready,
    output wire [31:0] nn_rdata,
    output wire [63:0] result0,
    output wire [63:0] result1
);

    //==========================================================================
    // MMIO wrapper signals
    //==========================================================================

    wire        axis_start;

    wire [63:0] weight0;
    wire [63:0] weight1;
    wire [63:0] weight2;
    wire [63:0] weight3;
    wire [63:0] weight4;

    wire [63:0] input0;
    wire [63:0] input1;

    wire        axis_busy;
    wire        axis_done;



    //==========================================================================
    // AXI4-Stream signals between packet master and axis_nn
    //==========================================================================

    wire        in_tvalid;
    wire        in_tready;
    wire [63:0] in_tdata;
    wire        in_tlast;

    wire        out_tvalid;
    wire        out_tready;
    wire [63:0] out_tdata;
    wire        out_tlast;

    //==========================================================================
    // Result-beat counter
    //
    // axis_nn produces exactly two result words:
    //
    //     result beat 0 -> result0
    //     result beat 1 -> result1
    //
    // TLAST is expected on result beat 1.
    //==========================================================================

    reg result_count;

    //==========================================================================
    // Native MMIO register bank
    //==========================================================================

    nn_axi_wrapper #(
        .BASE_ADDR(BASE_ADDR)
    )
    u_nn_axi_wrapper
    (
        .clk        (clk),
        .rst_n      (rst_n),

        .bus_req    (nn_valid),
        .bus_write  (nn_write),
        .bus_addr   ({20'd0, nn_addr}),
        .bus_wdata  (nn_wdata),
        .bus_strb   (nn_strb),

        .bus_ready  (nn_ready),
        .bus_rdata  (nn_rdata),

        .axis_start (axis_start),

        .weight0    (weight0),
        .weight1    (weight1),
        .weight2    (weight2),
        .weight3    (weight3),
        .weight4    (weight4),

        .input0     (input0),
        .input1     (input1),

        .axis_busy  (axis_busy),
        .axis_done  (axis_done),

        .result0    (result0),
        .result1    (result1)
    );

    //==========================================================================
    // AXI4-Stream packet generator
    //==========================================================================

    nn_axis_master
    u_nn_axis_master
    (
        .clk            (clk),
        .rst_n          (rst_n),

        .axis_start     (axis_start),

        .weight0        (weight0),
        .weight1        (weight1),
        .weight2        (weight2),
        .weight3        (weight3),
        .weight4        (weight4),

        .input0         (input0),
        .input1         (input1),

        // AXIS input packet toward axis_nn
        .m_axis_tvalid  (in_tvalid),
        .m_axis_tready  (in_tready),
        .m_axis_tdata   (in_tdata),
        .m_axis_tlast   (in_tlast),

        // AXIS result stream from axis_nn
        .s_axis_tvalid  (out_tvalid),
        .s_axis_tready  (out_tready),
        .s_axis_tdata   (out_tdata),
        .s_axis_tlast   (out_tlast),

        .axis_busy      (axis_busy),
        .axis_done      (axis_done),
        .result0         (result0),
        .result1         (result1)
    );

    //==========================================================================
    // Existing AXI-stream NN accelerator
    //
    // DO NOT modify this hierarchy by adding another nn instance.
    //
    // axis_nn already contains:
    //
    //     xpm_fifo_axis
    //     nn
    //     xpm_fifo_axis
    //==========================================================================

    axis_nn
    u_axis_nn
    (
        .aclk           (clk),
        .aresetn        (rst_n),

        // Input AXIS
        .s_axis_tready  (in_tready),
        .s_axis_tdata   (in_tdata),
        .s_axis_tvalid  (in_tvalid),
        .s_axis_tlast   (in_tlast),

        // Output AXIS
        .m_axis_tready  (out_tready),
        .m_axis_tdata   (out_tdata),
        .m_axis_tvalid  (out_tvalid),
        .m_axis_tlast   (out_tlast)
    );

    // //==========================================================================
    // // Result capture
    // //==========================================================================

    // always @(posedge clk or negedge rst_n) begin

    //     if (!rst_n) begin

    //         result0     <= 64'd0;
    //         result1     <= 64'd0;
    //         result_count <= 1'b0;

    //     end

    //     else begin

    //         if (axis_done) begin
    //             result_count <= 1'b0;
    //         end

    //         // AXI4-Stream result handshake
    //         if (out_tvalid && out_tready) begin

    //             if (!result_count) begin

    //                 // First result beat.
    //                 result0 <= out_tdata;
    //                 result_count <= 1'b1;

    //             end

    //             else begin

    //                 // Second/final result beat.
    //                 result1 <= out_tdata;
    //                 result_count <= 1'b0;

    //             end
    //         end
    //     end
  //  end

endmodule
`endif