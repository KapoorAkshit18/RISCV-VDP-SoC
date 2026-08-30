`ifndef SOC_REG_PREDICTOR_SV
`define SOC_REG_PREDICTOR_SV

// =============================================================================
// RISCV-VDP-SoC
// UVM RAL Predictor
//
// Converts monitored native-bus transactions into RAL mirror predictions.
//
// Monitor:
//     soc_sequence_item
//             |
//             v
//     soc_reg_predictor
//             |
//       soc_reg_adapter
//             |
//             v
//       uvm_reg_bus_op
//             |
//             v
//       RAL register model
// =============================================================================

class soc_reg_predictor extends uvm_reg_predictor #(soc_sequence_item);

    `uvm_component_utils(soc_reg_predictor)


    function new(
        string name = "soc_reg_predictor",
        uvm_component parent = null
    );

        super.new(name, parent);

    endfunction

endclass

`endif