`ifndef SOC_COVERAGE_SV
`define SOC_COVERAGE_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"


// =============================================================================
// RISCV-VDP-SoC
// UVM Functional Coverage
//
// Coverage is collected from transactions observed by soc_monitor.
//
// Monitor
//    |
//    +----> RAL Predictor
//    |
//    +----> soc_coverage
//
// No scoreboard is required for functional coverage.
//
// Fixes applied in this revision:
//   - cp_ready now has NOT_READY so ready==0 is counted instead of invisible
//     (currently the monitor only publishes valid&&ready transactions, so
//     NOT_READY will stay ZERO unless the monitor is changed to also publish
//     wait-state cycles; the bin is added so that gap is visible, not hidden)
//   - target_bin=6 (decode failure, i.e. tr.target matched no known string)
//     is now split from target_bin=7 (a real "UNMAPPED" address) via
//     illegal_bins UNKNOWN, so a monitor/decode bug fails loudly instead of
//     silently landing in the same bin as legitimate unmapped accesses
//   - cp_addr peripheral bins are now register-window ranges instead of a
//     single base address, plus an OTHER catch-all so an address outside
//     every known window is visible instead of uncounted
//   - cross_addr_target added to catch target_bin/addr disagreement
// =============================================================================

class soc_coverage extends uvm_subscriber #(soc_sequence_item);

    `uvm_component_utils(soc_coverage)


    // =========================================================================
    // Transaction received from monitor
    // =========================================================================

    soc_sequence_item tr;

    // Numeric representation of transaction target
    //   0=RAM 1=GPIO 2=RF 3=SENSOR 4=VDP 5=TPU 6=UNMAPPED(real) 7=UNKNOWN(decode failure)
    int target_bin;


    // =========================================================================
    // Functional Coverage
    // =========================================================================

    covergroup soc_cg;

        // ---------------------------------------------------------------------
        // READ / WRITE coverage
        // ---------------------------------------------------------------------

        cp_write: coverpoint tr.write {

            bins READ  = {1'b0};
            bins WRITE = {1'b1};

        }


        // ---------------------------------------------------------------------
        // Target coverage
        // ---------------------------------------------------------------------

        cp_target: coverpoint target_bin {

            bins RAM      = {0};
            bins GPIO     = {1};
            bins RF       = {2};
            bins SENSOR   = {3};
            bins VDP      = {4};
            bins TPU      = {5};
            bins UNMAPPED = {6};

            // target_bin==7 only happens if tr.target matched no known
            // string in write() below (a real decode/monitor bug) -
            // illegal so it fails the run instead of vanishing silently
            illegal_bins UNKNOWN = {7};

        }


        // ---------------------------------------------------------------------
        // Write strobe coverage
        // ---------------------------------------------------------------------

        cp_strb: coverpoint tr.strb {

            bins READ_STRB = {4'b0000};

            bins BYTE0 = {4'b0001};
            bins BYTE1 = {4'b0010};
            bins BYTE2 = {4'b0100};
            bins BYTE3 = {4'b1000};

            bins HALFWORD_LOW  = {4'b0011};
            bins HALFWORD_HIGH = {4'b1100};

            bins FULL_WORD = {4'b1111};

            bins OTHER = default;

        }


        // ---------------------------------------------------------------------
        // Address coverage
        //
        // Peripheral bins are 4 KB register windows (matching the address
        // map used elsewhere: GPIO/RF/SENSOR/VDP/TPU each own a 0x1000
        // window). Adjust the window size per bin if any peripheral's
        // actual decoded range differs.
        // ---------------------------------------------------------------------

        cp_addr: coverpoint tr.addr {

            bins RAM_BASE = {
                32'h0000_0000
            };

            bins RAM_LOW = {
                [32'h0000_0001 : 32'h0000_00FF]
            };

            bins GPIO_RANGE = {
                [32'h0001_0000 : 32'h0001_0FFF]
            };

            bins RF_RANGE = {
                [32'h0001_1000 : 32'h0001_1FFF]
            };

            bins SENSOR_RANGE = {
                [32'h0001_2000 : 32'h0001_2FFF]
            };

            bins VDP_RANGE = {
                [32'h0001_3000 : 32'h0001_3FFF]
            };

            bins TPU_RANGE = {
                [32'h0001_4000 : 32'h0001_4FFF]
            };

            bins UNMAPPED = {
                32'h0002_0000
            };

            // Any address outside every window above is now visible here
            // instead of being silently uncounted.
            bins OTHER_UNMAPPED = default;

        }


        // ---------------------------------------------------------------------
        // Write data pattern coverage
        // ---------------------------------------------------------------------

        cp_wdata: coverpoint tr.wdata iff (tr.write) {

            bins ZERO = {
                32'h0000_0000
            };

            bins ONES = {
                32'hFFFF_FFFF
            };

            bins AA = {
                32'hAAAA_AAAA
            };

            bins FIVE = {
                32'h5555_5555
            };

            bins OTHER = default;

        }


        // ---------------------------------------------------------------------
        // Response / ready coverage
        //
        // NOT_READY is added so ready==0 is a counted bin rather than an
        // invisible gap. Note: soc_monitor currently only calls write() when
        // (m_valid && m_ready), so NOT_READY cannot be hit until the monitor
        // is extended to also publish wait-state cycles - the bin's presence
        // makes that limitation visible in the report instead of hidden.
        // ---------------------------------------------------------------------

        cp_ready: coverpoint tr.ready {

            bins READY     = {1'b1};
            bins NOT_READY = {1'b0};

        }


        // =========================================================================
        // Cross Coverage
        // =========================================================================

        // Read / Write x Target
        cross_rw_target:
            cross cp_write, cp_target;


        // Address x Target - catches target_bin/addr disagreement
        // (e.g. tr.target says SENSOR but tr.addr falls in the TPU window)
        cross_addr_target:
            cross cp_addr, cp_target;


        // Write x Strobe
        cross_write_strb: cross cp_write, cp_strb {

            ignore_bins read_byte0 =
                binsof(cp_write.READ) &&
                binsof(cp_strb.BYTE0);

            ignore_bins read_byte1 =
                binsof(cp_write.READ) &&
                binsof(cp_strb.BYTE1);

            ignore_bins read_byte2 =
                binsof(cp_write.READ) &&
                binsof(cp_strb.BYTE2);

            ignore_bins read_byte3 =
                binsof(cp_write.READ) &&
                binsof(cp_strb.BYTE3);

            ignore_bins read_halfword_low =
                binsof(cp_write.READ) &&
                binsof(cp_strb.HALFWORD_LOW);

            ignore_bins read_halfword_high =
                binsof(cp_write.READ) &&
                binsof(cp_strb.HALFWORD_HIGH);

            ignore_bins read_full_word =
                binsof(cp_write.READ) &&
                binsof(cp_strb.FULL_WORD);

            ignore_bins write_read_strb =
                binsof(cp_write.WRITE) &&
                binsof(cp_strb.READ_STRB);
        }


        // Write x Target x Strobe - still omitted for complexity, as before


    endgroup


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(
        string name = "soc_coverage",
        uvm_component parent = null
    );

        super.new(name, parent);

        soc_cg = new();

    endfunction


    // =========================================================================
    // Receive transaction from monitor
    // =========================================================================

    virtual function void write(
        soc_sequence_item t
    );

        tr = t;


        // ---------------------------------------------------------------------
        // Convert string target to numeric coverage value
        // ---------------------------------------------------------------------

        case (tr.target)

            "RAM":
                target_bin = 0;

            "GPIO":
                target_bin = 1;

            "RF":
                target_bin = 2;

            "SENSOR":
                target_bin = 3;

            "VDP":
                target_bin = 4;

            "TPU":
                target_bin = 5;

            "UNMAPPED":
                target_bin = 6;

            // tr.target didn't match any known string - a real decode
            // problem, not a legitimate unmapped access. Kept separate
            // from bin 6 (illegal_bins UNKNOWN above) so it fails loudly.
            default:
                target_bin = 7;

        endcase


        // ---------------------------------------------------------------------
        // Sample coverage
        // ---------------------------------------------------------------------

        soc_cg.sample();


        `uvm_info(
            "COVERAGE",
            $sformatf(
                "Coverage sampled: target=%s write=%0b addr=0x%08h strb=0x%1h",
                tr.target,
                tr.write,
                tr.addr,
                tr.strb
            ),
            UVM_HIGH
        )

    endfunction


    // =========================================================================
    // Coverage report
    // =========================================================================

    virtual function void report_phase(
        uvm_phase phase
    );

        super.report_phase(phase);


        `uvm_info(
            "FUNCTIONAL_COVERAGE",
            $sformatf(
                "SoC Functional Coverage = %0.2f%%",
                soc_cg.get_inst_coverage()
            ),
            UVM_NONE
        )

    endfunction


endclass


`endif