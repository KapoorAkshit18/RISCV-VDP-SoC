`ifndef TPU_DEBUG_IF_SV
`define TPU_DEBUG_IF_SV

interface tpu_debug_if (
    input logic clk
);

    // TPU control/status
    logic axis_start;
    logic axis_busy;
    logic axis_done;

    // AXI4-Stream input: nn_axis_master -> axis_nn
    logic        in_tvalid;
    logic        in_tready;
    logic [63:0] in_tdata;
    logic        in_tlast;

    // AXI4-Stream output: axis_nn -> nn_axis_master
    logic        out_tvalid;
    logic        out_tready;
    logic [63:0] out_tdata;
    logic        out_tlast;

    // Captured TPU results
    logic [63:0] result0;
    logic [63:0] result1;

endinterface

`endif