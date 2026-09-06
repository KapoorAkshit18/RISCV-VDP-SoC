`timescale 1ns/1ps

// =============================================================================
// tb_cpu_soc_ram_top.sv
//
// Integration smoke test for:
//
//      PicoRV32
//          |
//      CPU Bus Adapter
//          |
//      SoC Memory Interconnect
//       /    |      |       |       \
//     RAM  GPIO   SENSOR    RF      VDP
//
// This testbench:
//   1. Drives all external DUT inputs.
//   2. Connects all DUT outputs.
//   3. Verifies reset behavior.
//   4. Verifies CPU startup.
//   5. Verifies no unexpected trap.
//   6. Provides sensor/RF/GPIO inputs.
//   7. Provides the independent VDP pixel clock.
//
// NOTE:
// Actual peripheral register transactions occur only if the program
// inside the ptb/PicoRV32 wrapper performs those accesses.
// =============================================================================

module tb_soc_ram_top;

    // =========================================================================
    // Parameters
    // =========================================================================

    localparam ADDR_WIDTH     = 32;
    localparam DATA_WIDTH     = 32;
    localparam RAM_ADDR_WIDTH = 16;
    localparam RAM_DEPTH      = 16384;
    localparam GPIO_WIDTH     = 32;


    // =========================================================================
    // System clock / reset
    // =========================================================================

    reg clk;
    reg resetn;


    // =========================================================================
    // VDP pixel clock
    //
    // Independent from the CPU/system clock.
    // 25 MHz equivalent pixel clock for smoke testing.
    // =========================================================================

    reg pixel_clk;


    // =========================================================================
    // Sensor inputs
    // =========================================================================

    reg [7:0]  battery_percent;
    reg [15:0] battery_voltage;
    reg [15:0] temperature;
    reg        sensor_valid;


    // =========================================================================
    // RF telemetry inputs
    // =========================================================================

    reg [7:0] rssi_dbm;
    reg       link_up;
    reg       link_error;
    reg       carrier_detect;


    // =========================================================================
    // GPIO input
    // =========================================================================

    reg [GPIO_WIDTH-1:0] gpio_in;


    // =========================================================================
    // DUT outputs
    // =========================================================================

    wire                    rf_enable_o;

    wire [GPIO_WIDTH-1:0]   gpio_out;
    wire [GPIO_WIDTH-1:0]   gpio_oe;

    wire                    hsync_o;
    wire                    vsync_o;

    wire [11:0]             pixel_x_o;
    wire [11:0]             pixel_y_o;

    wire [3:0]              rgb_r_o;
    wire [3:0]              rgb_g_o;
    wire [3:0]              rgb_b_o;

    wire                    trap;


    // =========================================================================
    // Error counter
    // =========================================================================

    integer errors;


    // =========================================================================
    // DUT
    // =========================================================================

    cpu_soc_ram_top #(
        .ADDR_WIDTH     (ADDR_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH),
        .RAM_ADDR_WIDTH (RAM_ADDR_WIDTH),
        .RAM_DEPTH      (RAM_DEPTH),
        .GPIO_WIDTH     (GPIO_WIDTH)
    ) dut (

        // ---------------------------------------------------------------------
        // System clock/reset
        // ---------------------------------------------------------------------

        .clk                   (clk),
        .resetn                (resetn),

        // ---------------------------------------------------------------------
        // Sensor
        // ---------------------------------------------------------------------

        .battery_percent_i     (battery_percent),
        .battery_voltage_mv_i  (battery_voltage),
        .temperature_tenthsC_i (temperature),
        .sensor_valid_i        (sensor_valid),

        // ---------------------------------------------------------------------
        // RF
        // ---------------------------------------------------------------------

        .rssi_dbm_i            (rssi_dbm),
        .link_up_i             (link_up),
        .link_error_i          (link_error),
        .carrier_detect_i      (carrier_detect),

        .rf_enable_o           (rf_enable_o),

        // ---------------------------------------------------------------------
        // GPIO
        // ---------------------------------------------------------------------

        .gpio_out              (gpio_out),
        .gpio_oe               (gpio_oe),
        .gpio_in               (gpio_in),

        // ---------------------------------------------------------------------
        // VDP / VGA
        // ---------------------------------------------------------------------

        .pixel_clk             (pixel_clk),

        .hsync_o               (hsync_o),
        .vsync_o               (vsync_o),

        .pixel_x_o             (pixel_x_o),
        .pixel_y_o             (pixel_y_o),

        .rgb_r_o               (rgb_r_o),
        .rgb_g_o               (rgb_g_o),
        .rgb_b_o               (rgb_b_o),

        // ---------------------------------------------------------------------
        // CPU status
        // ---------------------------------------------------------------------

        .trap                  (trap)
    );


    // =========================================================================
    // Load firmware into RAM
    // =========================================================================

    initial begin
    $readmemh("../../phase_1/firmware_test2/firmware.hex", dut.ram.mem);
    end




    // =========================================================================
    // System clock
    //
    // 100 MHz
    // Period = 10 ns
    // =========================================================================

    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end


    // =========================================================================
    // Pixel clock
    //
    // 25 MHz
    // Period = 40 ns
    // =========================================================================

    initial begin
        pixel_clk = 1'b0;

        forever #20 pixel_clk = ~pixel_clk;
    end
    always @(posedge clk) begin
        if (dut.m_valid && !dut.m_write) begin
            $display("CPU READ: addr=%h ready=%b rdata=%h",
                    dut.m_addr,
                    dut.m_ready,
                    dut.m_rdata);

            if (dut.m_addr == 32'h0001_2000)
                $display("***** SENSOR READ FOUND *****");
        end
    end

    // =========================================================================
    // Main test
    // =========================================================================

    initial begin

        errors = 0;


        // =====================================================================
        // Initial conditions
        // =====================================================================

        resetn = 1'b0;

        // Sensor
        battery_percent = 8'd67;
        battery_voltage = 16'd3700;
        temperature     = 16'sd235;
        sensor_valid    = 1'b1;

        // RF
        rssi_dbm        = 8'd200;
        link_up         = 1'b1;
        link_error      = 1'b0;
        carrier_detect  = 1'b1;

        // GPIO
        gpio_in         = 32'hA5A5_5A5A;


        $display("");
        $display("======================================================");
        $display("       TB_CPU_SOC_RAM_TOP");
        $display("       RISCV-VDP-SoC INTEGRATION TEST");
        $display("======================================================");
        $display("");


        // =====================================================================
        // Reset
        // =====================================================================

        $display("INFO: Applying reset...");

        repeat (5) @(posedge clk);


        // ---------------------------------------------------------------------
        // Trap must remain low during reset
        // ---------------------------------------------------------------------

        if (trap === 1'b0) begin
            $display("PASS: trap low during reset");
        end
        else begin
            $display("FAIL: trap asserted during reset");
            errors = errors + 1;
        end


        // =====================================================================
        // Release reset
        // =====================================================================

        resetn = 1'b1;

        $display("INFO: reset released");


        // =====================================================================
        // CPU startup
        // =====================================================================

        repeat (20) @(posedge clk);


        if (trap === 1'b0) begin
            $display("PASS: trap remains low after CPU startup");
        end
        else begin
            $display("FAIL: trap asserted after CPU startup");
            errors = errors + 1;
        end


        // =====================================================================
        // Check GPIO input connection
        // =====================================================================

        $display("");
        $display("INFO: GPIO input = %h", gpio_in);


        // =====================================================================
        // Check RF input configuration
        // =====================================================================

        $display("INFO: RF inputs:");
        $display("      RSSI           = %0d", rssi_dbm);
        $display("      link_up        = %b", link_up);
        $display("      link_error     = %b", link_error);
        $display("      carrier_detect = %b", carrier_detect);


        // =====================================================================
        // Check sensor configuration
        // =====================================================================

        $display("");
        $display("INFO: Sensor inputs:");
        $display("      battery_percent = %0d", battery_percent);
        $display("      battery_voltage = %0d mV", battery_voltage);
        $display("      temperature     = %0d tenths C", temperature);
        $display("      sensor_valid    = %b", sensor_valid);


        // =====================================================================
        // Allow system to execute
        // =====================================================================

        repeat (50) @(posedge clk);


        // =====================================================================
        // Trap check
        // =====================================================================

        if (trap === 1'b0) begin
            $display("PASS: CPU/system remains running without trap");
        end
        else begin
            $display("FAIL: trap asserted during extended execution");
            errors = errors + 1;
        end


        // =====================================================================
        // Change sensor inputs
        // =====================================================================

        battery_percent = 8'd10;
        battery_voltage = 16'd3300;
        temperature     = 16'sd801;
        sensor_valid    = 1'b1;


        repeat (10) @(posedge clk);


        $display("");
        $display("INFO: Sensor inputs changed:");
        $display("      battery_percent = %0d", battery_percent);
        $display("      battery_voltage = %0d mV", battery_voltage);
        $display("      temperature     = %0d tenths C", temperature);
        $display("      sensor_valid    = %b", sensor_valid);


        // =====================================================================
        // Change RF inputs
        // =====================================================================

        rssi_dbm       = 8'd180;
        link_up        = 1'b0;
        link_error     = 1'b1;
        carrier_detect = 1'b0;


        repeat (10) @(posedge clk);


        $display("");
        $display("INFO: RF inputs changed:");
        $display("      RSSI           = %0d", rssi_dbm);
        $display("      link_up        = %b", link_up);
        $display("      link_error     = %b", link_error);
        $display("      carrier_detect = %b", carrier_detect);


        // =====================================================================
        // Change GPIO inputs
        // =====================================================================

        gpio_in = 32'h1234_5678;


        repeat (10) @(posedge clk);


        $display("");
        $display("INFO: GPIO input changed = %h", gpio_in);


        // =====================================================================
        // Final trap check
        // =====================================================================

        repeat (20) @(posedge clk);


        if (trap === 1'b0) begin
            $display("PASS: system remains stable after input changes");
        end
        else begin
            $display("FAIL: trap asserted after input changes");
            errors = errors + 1;
        end


        // =====================================================================
        // Final result
        // =====================================================================

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


//        $finish;
        $display("Extended time for more testcases");
    end

endmodule