`timescale 1ns/1ps

// =============================================================================
// RISCV-VDP-SoC
// Standalone UVM Top-Level Testbench
// =============================================================================
//
// PURPOSE
// -------
// This module provides the simulation top-level required by QuestaSim/vsim.
//
// UVM classes such as:
//   - soc_tpu_scoreboard
//   - soc_env
//   - soc_tpu_test
//
// are SystemVerilog classes, not simulation top-level modules.
//
// Questa therefore needs a module containing an initial block that calls
// run_test() to start the UVM simulation.
//
// =============================================================================
// SIMULATION HIERARCHY
// =============================================================================
//
//                         tb
//                          |
//                          v
//                      run_test()
//                          |
//                          v
//                  soc_tpu_test
//                          |
//                          v
//                 TPU scoreboard test
//
// For the independent scoreboard test, the scoreboard can be exercised
// directly by the UVM test/sequence without instantiating the complete SoC.
//
// =============================================================================
// IMPORTANT
// ---------
// This module does NOT modify:
//
//   - soc_tpu_scoreboard.sv
//   - DPI C reference model
//   - soc_sequence_item.sv
//   - soc_env.sv
//   - TPU RTL
//
// It only starts the UVM test selected from the Questa command line.
//
// =============================================================================

module tb;

    // =========================================================================
    // START UVM
    // =========================================================================
    //
    // run_test() starts the UVM phasing mechanism.
    //
    // The actual test can be selected from Questa using:
    //
    //     +UVM_TESTNAME=soc_tpu_test
    //
    // This keeps the top-level module reusable.
    //
    // =========================================================================

    initial begin

        // Start the UVM test selected through +UVM_TESTNAME.
        run_test();

    end

endmodule