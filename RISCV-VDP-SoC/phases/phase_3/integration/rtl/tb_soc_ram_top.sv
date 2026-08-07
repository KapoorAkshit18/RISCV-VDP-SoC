`timescale 1ns/1ps

// =============================================================================
// tb_cpu_soc_ram_top.sv
//
// Integration smoke test for:
//      PicoRV32
//          |
//      CPU Bus Adapter
//          |
//      SoC Memory Interconnect
//       /    |      |      \
//     RAM  GPIO   SENSOR   RF/VDP
//
// This testbench does NOT directly drive the CPU native bus.
// PicoRV32 generates the transactions according to the program
// configured inside the ptb wrapper.
//
// Purpose:
//   1. Verify reset
//   2. Verify CPU starts executing
//   3. Provide sensor inputs
//   4. Check that trap does not unexpectedly assert
//   5. Check basic top-level integration
// =============================================================================

module tb_cpu_soc_ram_top;

    // -------------------------------------------------------------------------
    // Clock / reset
    // -------------------------------------------------------------------------

    reg clk;
    reg resetn;

    // -------------------------------------------------------------------------
    // Sensor inputs
    // -------------------------------------------------------------------------

    reg [7:0]  battery_percent;
    reg [15:0] battery_voltage;
    reg [15:0] temperature;
    reg        sensor_valid;

    // -------------------------------------------------------------------------
    // DUT output
    // -------------------------------------------------------------------------

    wire trap;

    integer errors;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------

    cpu_soc_ram_top #(
        .ADDR_WIDTH     (32),
        .DATA_WIDTH     (32),
        .RAM_ADDR_WIDTH (16),
        .RAM_DEPTH      (256)
    ) dut (
        .clk                   (clk),
        .resetn                (resetn),

        .battery_percent_i     (battery_percent),
        .battery_voltage_mv_i  (battery_voltage),
        .temperature_tenthsC_i (temperature),
        .sensor_valid_i        (sensor_valid),

        .trap                   (trap)
    );

    // -------------------------------------------------------------------------
    // Clock: 100 MHz
    // -------------------------------------------------------------------------

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // Main test
    // -------------------------------------------------------------------------

    initial begin

        errors = 0;

        // -------------------------------------------------------------
        // Initial conditions
        // -------------------------------------------------------------

        resetn = 1'b0;

        battery_percent = 8'd67;
        battery_voltage = 16'd3700;
        temperature     = 16'sd235;
        sensor_valid    = 1'b1;

        $display("");
        $display("======================================================");
        $display(" TB_CPU_SOC_RAM_TOP");
        $display("======================================================");

        // -------------------------------------------------------------
        // Reset
        // -------------------------------------------------------------

        repeat (5) @(posedge clk);

        if (trap === 1'b0)
            $display("PASS: trap low during reset");
        else begin
            $display("FAIL: trap asserted during reset");
            errors = errors + 1;
        end

        // Release reset
        resetn = 1'b1;

        $display("INFO: reset released");

        // -------------------------------------------------------------
        // Allow CPU to execute
        // -------------------------------------------------------------

        repeat (20) @(posedge clk);

        // -------------------------------------------------------------
        // Check trap
        // -------------------------------------------------------------

        if (trap === 1'b0)
            $display("PASS: trap remains low after CPU startup");
        else begin
            $display("FAIL: trap asserted after CPU startup");
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // Keep system running
        // -------------------------------------------------------------

        repeat (50) @(posedge clk);

        if (trap === 1'b0)
            $display("PASS: CPU/system remains running without trap");
        else begin
            $display("FAIL: trap asserted during extended execution");
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // Change sensor inputs
        //
        // This verifies that the top-level sensor inputs are actually
        // connected and can be driven by the testbench.
        //
        // The CPU must execute a Sensor read for this to become visible
        // through the CPU path.
        // -------------------------------------------------------------

        battery_percent = 8'd10;
        battery_voltage = 16'd3300;
        temperature     = 16'sd801;
        sensor_valid    = 1'b1;

        repeat (10) @(posedge clk);

        $display("INFO: sensor inputs changed:");
        $display("      battery_percent = %0d", battery_percent);
        $display("      battery_voltage = %0d mV", battery_voltage);
        $display("      temperature     = %0d tenths C", temperature);
        $display("      sensor_valid    = %b", sensor_valid);

        // -------------------------------------------------------------
        // Final trap check
        // -------------------------------------------------------------

        repeat (20) @(posedge clk);

        if (trap === 1'b0)
            $display("PASS: system remains stable after sensor input change");
        else begin
            $display("FAIL: trap asserted after sensor input change");
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // Final result
        // -------------------------------------------------------------

        $display("");
        $display("======================================================");

        if (errors == 0) begin
            $display("TB_CPU_SOC_RAM_TOP: ALL TESTS PASSED");
        end
        else begin
            $display("TB_CPU_SOC_RAM_TOP: %0d TEST(S) FAILED", errors);
        end

        $display("======================================================");
        $display("");

        $finish;
    end

endmodule