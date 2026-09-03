`timescale 1ns / 1ps

// =============================================================================
// tb_cpu_soc_ram_top.v
//
// LEVEL-1 MANUAL PERIPHERAL INTEGRATION TESTBENCH
// =============================================================================
//
// PURPOSE
// -------
// This testbench verifies the PERIPHERAL INTEGRATION of cpu_soc_ram_top
// WITHOUT using firmware.
//
// No firmware.hex is required.
// No PicoRV32 instruction execution is required.
// No software-generated MMIO transactions are required.
//
// Instead, the testbench manually drives the native master-side bus signals
// entering the SoC memory interconnect.
//
//
//
//                  LEVEL-1 VERIFICATION PATH
//
//                         TESTBENCH
//                             |
//                             |
//                   Manual native bus
//                  m_valid/m_write/etc.
//                             |
//                             v
//                  +--------------------+
//                  | SoC Memory         |
//                  | Interconnect       |
//                  +--------------------+
//                    |    |    |    |   |   |
//                    v    v    v    v   v   v
//                   RAM GPIO   RF SENSOR VDP TPU
//
//
// The following are intentionally NOT verified here:
//
//   - PicoRV32 instruction execution
//   - firmware
//   - firmware.hex
//   - compiler/toolchain
//   - AXI DMA
//   - neural-network numerical correctness
//   - FPGA timing
//   - TPU performance
//
// Those belong to later verification levels.
//
// =============================================================================
//
// ADDRESS MAP
// ----------
//
//   0x0000_0000 - 0x0000_FFFF : RAM
//   0x0001_0000 - 0x0001_0FFF : GPIO
//   0x0001_1000 - 0x0001_1FFF : RF
//   0x0001_2000 - 0x0001_2FFF : SENSOR
//   0x0001_3000 - 0x0001_3FFF : VDP
//   0x0001_4000 - 0x0001_4FFF : TPU
//
// =============================================================================
//
// TEST PHILOSOPHY
// ---------------
//
// Every manual transaction follows:
//
//       DRIVE
//         |
//         v
//       WAIT
//         |
//         v
//       CHECK DECODE
//         |
//         v
//       CHECK READY
//         |
//         v
//       CHECK DATA
//         |
//         v
//       RELEASE
//         |
//         v
//       GUARD BAND
//
// This prevents a transaction from leaking into the next test.
//
// =============================================================================


module tb_cpu_soc_ram_top;


    // =========================================================================
    // 1. CLOCKS
    // =========================================================================

    reg clk;
    reg pixel_clk;


    // -------------------------------------------------------------------------
    // 100 MHz system clock
    //
    // Period = 10 ns
    // -------------------------------------------------------------------------

    initial begin
        clk = 1'b0;

        forever
            #5 clk = ~clk;
    end


    // -------------------------------------------------------------------------
    // 25 MHz pixel clock
    //
    // Period = 40 ns
    //
    // VDP requires this clock even though Level-1 MMIO verification does not
    // perform complete VGA functional verification.
    // -------------------------------------------------------------------------

    initial begin
        pixel_clk = 1'b0;

        forever
            #20 pixel_clk = ~pixel_clk;
    end


    // =========================================================================
    // 2. RESET
    // =========================================================================

    reg resetn;


    // =========================================================================
    // 3. SENSOR INPUTS
    // =========================================================================

    reg [7:0]  battery_percent_i;
    reg [15:0] battery_voltage_mv_i;
    reg [15:0] temperature_tenthsC_i;
    reg        sensor_valid_i;


    // =========================================================================
    // 4. RF INPUTS
    // =========================================================================

    reg [7:0] rssi_dbm_i;
    reg       link_up_i;
    reg       link_error_i;
    reg       carrier_detect_i;


    // =========================================================================
    // 5. GPIO INPUT
    // =========================================================================

    reg [31:0] gpio_in;


    // =========================================================================
    // 6. DUT OUTPUTS
    // =========================================================================

    wire        rf_enable_o;

    wire [31:0] gpio_out;
    wire [31:0] gpio_oe;

    wire        hsync_o;
    wire        vsync_o;

    wire [11:0] pixel_x_o;
    wire [11:0] pixel_y_o;

    wire [3:0] rgb_r_o;
    wire [3:0] rgb_g_o;
    wire [3:0] rgb_b_o;

    wire trap;


    // =========================================================================
    // 7. DUT
    // =========================================================================
    //
    // Exact current cpu_soc_ram_top port interface.
    //
    // No firmware connection exists here.
    //
    // =========================================================================

    cpu_soc_ram_top #(
        .ADDR_WIDTH     (32),
        .DATA_WIDTH     (32),
        .RAM_ADDR_WIDTH (16),
        .RAM_DEPTH      (16384),
        .GPIO_WIDTH     (32)
    ) dut (

        .clk                   (clk),
        .resetn                (resetn),

        // Sensor
        .battery_percent_i     (battery_percent_i),
        .battery_voltage_mv_i  (battery_voltage_mv_i),
        .temperature_tenthsC_i (temperature_tenthsC_i),
        .sensor_valid_i        (sensor_valid_i),

        // RF
        .rssi_dbm_i            (rssi_dbm_i),
        .link_up_i             (link_up_i),
        .link_error_i          (link_error_i),
        .carrier_detect_i      (carrier_detect_i),

        .rf_enable_o           (rf_enable_o),

        // GPIO
        .gpio_out              (gpio_out),
        .gpio_oe               (gpio_oe),
        .gpio_in               (gpio_in),

        // VDP
        .pixel_clk             (pixel_clk),
        .hsync_o               (hsync_o),
        .vsync_o               (vsync_o),
        .pixel_x_o             (pixel_x_o),
        .pixel_y_o             (pixel_y_o),
        .rgb_r_o               (rgb_r_o),
        .rgb_g_o               (rgb_g_o),
        .rgb_b_o               (rgb_b_o),

        .trap                   (trap)
    );


    // =========================================================================
    // 8. ADDRESS MAP CONSTANTS
    // =========================================================================

    localparam [31:0] RAM_BASE    = 32'h0000_0000;
    localparam [31:0] GPIO_BASE   = 32'h0001_0000;
    localparam [31:0] RF_BASE     = 32'h0001_1000;
    localparam [31:0] SENSOR_BASE = 32'h0001_2000;
    localparam [31:0] VDP_BASE    = 32'h0001_3000;
    localparam [31:0] TPU_BASE    = 32'h0001_4000;

    localparam [31:0] RAM_LIMIT    = 32'h0000_FFFF;
    localparam [31:0] GPIO_LIMIT   = 32'h0001_0FFF;
    localparam [31:0] RF_LIMIT     = 32'h0001_1FFF;
    localparam [31:0] SENSOR_LIMIT = 32'h0001_2FFF;
    localparam [31:0] VDP_LIMIT    = 32'h0001_3FFF;
    localparam [31:0] TPU_LIMIT    = 32'h0001_4FFF;


    // =========================================================================
    // 9. MANUAL MASTER BUS
    // =========================================================================
    //
    // These are the internal signals between cpu_bus_adapter and
    // soc_mem_interconnect in the DUT.
    //
    // Normally:
    //
    //      PicoRV32
    //          |
    //      cpu_bus_adapter
    //          |
    //      m_*
    //
    // For Level 1:
    //
    //      TESTBENCH
    //          |
    //      m_*
    //          |
    //      soc_mem_interconnect
    //
    // We use hierarchical force/release so that the REAL interconnect and
    // REAL peripherals remain in the DUT.
    //
    // =========================================================================


    // =========================================================================
    // 10. TEST CONTROL PARAMETERS
    // =========================================================================

    localparam integer RESET_CYCLES      = 5;
    localparam integer READY_TIMEOUT     = 50;
    localparam integer GUARD_CYCLES      = 3;
    localparam integer FINAL_GUARD_CYCLES = 5;


    // =========================================================================
    // 11. TEST RESULT COUNTERS
    // =========================================================================

    integer total_tests;
    integer passed_tests;
    integer failed_tests;

    reg test_failed;


    // =========================================================================
    // 12. TEST REPORTING TASKS
    // =========================================================================

    task automatic pass_test;

        input [8*100-1:0] message;

        begin

            total_tests  = total_tests + 1;
            passed_tests = passed_tests + 1;

            $display(
                "[PASS] %0s",
                message
            );

        end

    endtask


    task automatic fail_test;

        input [8*100-1:0] message;

        begin

            total_tests  = total_tests + 1;
            failed_tests = failed_tests + 1;

            test_failed = 1'b1;

            $display(
                "[FAIL] %0s",
                message
            );

        end

    endtask


    // =========================================================================
    // 13. GUARD BAND
    // =========================================================================
    //
    // After every manual transaction, the bus is released and allowed to
    // remain idle for several system-clock cycles.
    //
    // This prevents:
    //
    //      previous transaction
    //
    // from being confused with:
    //
    //      next transaction
    //
    // =========================================================================

    task automatic guard_band;

        integer i;

        begin

            for (i = 0; i < GUARD_CYCLES; i = i + 1)
                @(posedge clk);

        end

    endtask


    // =========================================================================
    // 14. BUS RELEASE TASK
    // =========================================================================
    //
    // Return the manually driven master bus to an inactive state.
    //
    // =========================================================================

    task automatic release_master_bus;

        begin

            force dut.m_valid = 1'b0;
            force dut.m_write = 1'b0;
            force dut.m_addr  = 32'h0000_0000;
            force dut.m_wdata = 32'h0000_0000;
            force dut.m_strb  = 4'b0000;

        end

    endtask


    // =========================================================================
    // 15. MANUAL BUS WRITE
    // =========================================================================
    //
    // Performs one complete native-bus write.
    //
    // The task:
    //
    //   1. drives address/data/strobes
    //   2. asserts valid
    //   3. waits for ready
    //   4. checks expected slave decode
    //   5. releases the bus
    //   6. inserts guard band
    //
    // =========================================================================

    task automatic bus_write;

        input [31:0] address;
        input [31:0] data;
        input [3:0]  strb;

        input [2:0] expected_slave;

        integer wait_count;

        begin

            $display("");
            $display(
                "[WRITE] addr=%08h data=%08h strb=%b",
                address,
                data,
                strb
            );


            // -----------------------------------------------------------------
            // Drive transaction.
            // -----------------------------------------------------------------

            force dut.m_valid = 1'b1;
            force dut.m_write = 1'b1;
            force dut.m_addr  = address;
            force dut.m_wdata = data;
            force dut.m_strb  = strb;


            // -----------------------------------------------------------------
            // Allow combinational decode to settle.
            // -----------------------------------------------------------------

            #1;


            // -----------------------------------------------------------------
            // Verify expected decode.
            // -----------------------------------------------------------------

            case (expected_slave)

                3'd0: begin
                    if (dut.ram_valid !== 1'b1)
                        fail_test("RAM write: RAM was not selected");
                end

                3'd1: begin
                    if (dut.gpio_valid !== 1'b1)
                        fail_test("GPIO write: GPIO was not selected");
                end

                3'd2: begin
                    if (dut.rf_valid !== 1'b1)
                        fail_test("RF write: RF was not selected");
                end

                3'd3: begin
                    if (dut.sensor_valid !== 1'b1)
                        fail_test("SENSOR write: SENSOR was not selected");
                end

                3'd4: begin
                    if (dut.vdp_valid !== 1'b1)
                        fail_test("VDP write: VDP was not selected");
                end

                3'd5: begin
                    if (dut.nn_valid !== 1'b1)
                        fail_test("TPU write: TPU was not selected");
                end

                default: begin
                    fail_test("Invalid expected slave ID");
                end

            endcase


            // -----------------------------------------------------------------
            // Wait for selected slave to return ready.
            // -----------------------------------------------------------------

            wait_count = 0;

            while (
                (dut.m_ready !== 1'b1) &&
                (wait_count < READY_TIMEOUT)
            ) begin

                @(posedge clk);

                wait_count = wait_count + 1;

            end


            // -----------------------------------------------------------------
            // Timeout protection.
            // -----------------------------------------------------------------

            if (wait_count >= READY_TIMEOUT) begin

                fail_test(
                    "WRITE transaction timed out waiting for m_ready"
                );

            end
            else begin

                $display(
                    "[WRITE RESPONSE] ready=1 rdata=%08h",
                    dut.m_rdata
                );

            end


            // -----------------------------------------------------------------
            // Release transaction.
            // -----------------------------------------------------------------

            release_master_bus;

            guard_band;

        end

    endtask


    // =========================================================================
    // 16. MANUAL BUS READ
    // =========================================================================
    //
    // Performs one complete native-bus read.
    //
    // expected_data_valid:
    //
    //      1 -> compare returned data
    //      0 -> only verify routing/ready
    //
    // =========================================================================

    task automatic bus_read;

        input [31:0] address;

        input [2:0] expected_slave;

        input        expected_data_valid;
        input [31:0] expected_data;

        integer wait_count;

        begin

            $display("");
            $display(
                "[READ] addr=%08h",
                address
            );


            // -----------------------------------------------------------------
            // Drive read transaction.
            // -----------------------------------------------------------------
            //
            // Native-bus convention:
            //
            //      m_write = 0
            //      m_strb  = 0000
            //
            // -----------------------------------------------------------------

            force dut.m_valid = 1'b1;
            force dut.m_write = 1'b0;
            force dut.m_addr  = address;
            force dut.m_wdata = 32'h0000_0000;
            force dut.m_strb  = 4'b0000;


            // -----------------------------------------------------------------
            // Allow combinational decode to settle.
            // -----------------------------------------------------------------

            #1;


            // -----------------------------------------------------------------
            // Verify expected slave selection.
            // -----------------------------------------------------------------

            case (expected_slave)

                3'd0: begin
                    if (dut.ram_valid !== 1'b1)
                        fail_test("RAM read: RAM was not selected");
                end

                3'd1: begin
                    if (dut.gpio_valid !== 1'b1)
                        fail_test("GPIO read: GPIO was not selected");
                end

                3'd2: begin
                    if (dut.rf_valid !== 1'b1)
                        fail_test("RF read: RF was not selected");
                end

                3'd3: begin
                    if (dut.sensor_valid !== 1'b1)
                        fail_test("SENSOR read: SENSOR was not selected");
                end

                3'd4: begin
                    if (dut.vdp_valid !== 1'b1)
                        fail_test("VDP read: VDP was not selected");
                end

                3'd5: begin
                    if (dut.nn_valid !== 1'b1)
                        fail_test("TPU read: TPU was not selected");
                end

                default: begin
                    fail_test("Invalid expected slave ID");
                end

            endcase


            // -----------------------------------------------------------------
            // Wait for ready.
            // -----------------------------------------------------------------

            wait_count = 0;

            while (
                (dut.m_ready !== 1'b1) &&
                (wait_count < READY_TIMEOUT)
            ) begin

                @(posedge clk);

                wait_count = wait_count + 1;

            end


            // -----------------------------------------------------------------
            // Timeout.
            // -----------------------------------------------------------------

            if (wait_count >= READY_TIMEOUT) begin

                fail_test(
                    "READ transaction timed out waiting for m_ready"
                );

            end
            else begin

                $display(
                    "[READ RESPONSE] ready=1 rdata=%08h",
                    dut.m_rdata
                );


                // -------------------------------------------------------------
                // Optional data comparison.
                // -------------------------------------------------------------

                if (expected_data_valid) begin

                    if (dut.m_rdata !== expected_data) begin

                        $display(
                            "[DATA ERROR] expected=%08h actual=%08h",
                            expected_data,
                            dut.m_rdata
                        );

                        fail_test(
                            "READ data mismatch"
                        );

                    end
                    else begin

                        $display(
                            "[DATA MATCH] %08h",
                            dut.m_rdata
                        );

                    end

                end

            end


            // -----------------------------------------------------------------
            // Release transaction.
            // -----------------------------------------------------------------

            release_master_bus;

            guard_band;

        end

    endtask


    // =========================================================================
    // 17. INVALID ADDRESS TEST
    // =========================================================================
    //
    // Address:
    //
    //      0x0001_5000
    //
    // is outside every defined address window.
    //
    // Expected behavior according to the interconnect:
    //
    //      m_ready = 1
    //      m_rdata = 0
    //      all slave valid signals = 0
    //
    // =========================================================================

    task automatic invalid_read;

        input [31:0] address;

        integer wait_count;

        begin

            $display("");
            $display(
                "[INVALID READ] addr=%08h",
                address
            );


            force dut.m_valid = 1'b1;
            force dut.m_write = 1'b0;
            force dut.m_addr  = address;
            force dut.m_wdata = 32'h0000_0000;
            force dut.m_strb  = 4'b0000;


            #1;


            // -----------------------------------------------------------------
            // No peripheral must be selected.
            // -----------------------------------------------------------------

            if (
                (dut.ram_valid    !== 1'b0) ||
                (dut.gpio_valid   !== 1'b0) ||
                (dut.rf_valid     !== 1'b0) ||
                (dut.sensor_valid !== 1'b0) ||
                (dut.vdp_valid    !== 1'b0) ||
                (dut.nn_valid     !== 1'b0)
            ) begin

                fail_test(
                    "INVALID address incorrectly selected a peripheral"
                );

            end


            // -----------------------------------------------------------------
            // Interconnect should terminate unmapped access.
            // -----------------------------------------------------------------

            wait_count = 0;

            while (
                (dut.m_ready !== 1'b1) &&
                (wait_count < READY_TIMEOUT)
            ) begin

                @(posedge clk);

                wait_count = wait_count + 1;

            end


            if (wait_count >= READY_TIMEOUT) begin

                fail_test(
                    "INVALID address did not receive m_ready"
                );

            end
            else if (dut.m_rdata !== 32'h0000_0000) begin

                fail_test(
                    "INVALID address returned non-zero data"
                );

            end
            else begin

                pass_test(
                    "INVALID address correctly terminated"
                );

            end


            release_master_bus;

            guard_band;

        end

    endtask


    // =========================================================================
    // 18. INITIAL SIGNAL VALUES
    // =========================================================================

    initial begin

        resetn = 1'b0;


        // Sensor
        battery_percent_i     = 8'd75;
        battery_voltage_mv_i  = 16'd3700;
        temperature_tenthsC_i = 16'd250;
        sensor_valid_i        = 1'b1;


        // RF
        rssi_dbm_i       = 8'd200;
        link_up_i        = 1'b1;
        link_error_i     = 1'b0;
        carrier_detect_i = 1'b1;


        // GPIO
        gpio_in = 32'hA5A5_5A5A;


        // Test status
        total_tests  = 0;
        passed_tests = 0;
        failed_tests = 0;

        test_failed = 1'b0;

    end


    // =========================================================================
    // 19. MAIN LEVEL-1 TEST
    // =========================================================================

    initial begin : main_test

        integer i;

        // ---------------------------------------------------------------------
        // Keep the manual bus inactive initially.
        // ---------------------------------------------------------------------

        #1;

        release_master_bus;


        // ---------------------------------------------------------------------
        // RESET
        // ---------------------------------------------------------------------

        $display("");
        $display("============================================================");
        $display("LEVEL-1 MANUAL PERIPHERAL INTEGRATION TEST");
        $display("============================================================");

        $display("");
        $display("[INFO] No firmware is used.");
        $display("[INFO] CPU execution is intentionally bypassed.");
        $display("[INFO] Native master bus is manually driven.");
        $display("");


        for (i = 0; i < RESET_CYCLES; i = i + 1)
            @(posedge clk);


        resetn = 1'b1;


        guard_band;


        pass_test("RESET completed");


        // =====================================================================
        // TEST 1: RAM WRITE
        // =====================================================================

        bus_write(
            32'h0000_0100,
            32'h1234_5678,
            4'b1111,
            3'd0
        );

        pass_test("RAM write transaction completed");


        // =====================================================================
        // TEST 2: RAM READ
        // =====================================================================
        //
        // Because RAM is synchronous, allow the actual RAM response to return
        // before comparing the data.
        //
        // =====================================================================

        bus_read(
            32'h0000_0100,
            3'd0,
            1'b1,
            32'h1234_5678
        );

        pass_test("RAM read transaction completed");


        // =====================================================================
        // TEST 3: RAM BYTE-STROBE WRITE
        // =====================================================================
        //
        // Existing value:
        //
        //      1234_5678
        //
        // Write:
        //
        //      0000_AA00
        //
        // with:
        //
        //      0010
        //
        // Only byte lane 1 should be modified.
        //
        // Expected:
        //
        //      1234_AA78
        //
        // =====================================================================

        bus_write(
            32'h0000_0100,
            32'h0000_AA00,
            4'b0010,
            3'd0
        );

        pass_test("RAM byte-strobe write completed");


        bus_read(
            32'h0000_0100,
            3'd0,
            1'b1,
            32'h1234_AA78
        );

        pass_test("RAM byte-strobe readback verified");


        // =====================================================================
        // TEST 4: GPIO WRITE
        // =====================================================================
        //
        // GPIO base:
        //
        //      0x0001_0000
        //
        // =====================================================================

        bus_write(
            GPIO_BASE,
            32'hCAFE_BABE,
            4'b1111,
            3'd1
        );

        pass_test("GPIO write routed correctly");


        // =====================================================================
        // TEST 5: GPIO READ
        // =====================================================================
        //
        // GPIO input is externally driven:
        //
        //      A5A5_5A5A
        //
        // =====================================================================

        bus_read(
            GPIO_BASE,
            3'd1,
            1'b1,
            32'hA5A5_5A5A
        );

        pass_test("GPIO read routed correctly");


        // =====================================================================
        // TEST 6: RF READ
        // =====================================================================
        //
        // RF base:
        //
        //      0x0001_1000
        //
        // Exact returned value depends on the RF slave register map.
        //
        // Therefore Level 1 checks routing and response rather than assuming
        // a particular RF register encoding.
        //
        // =====================================================================

        bus_read(
            RF_BASE,
            3'd2,
            1'b0,
            32'h0000_0000
        );

        pass_test("RF read routed correctly");


        // =====================================================================
        // TEST 7: SENSOR READ
        // =====================================================================
        //
        // Sensor base:
        //
        //      0x0001_2000
        //
        // The sensor input values are driven externally.
        //
        // =====================================================================

        bus_read(
            SENSOR_BASE,
            3'd3,
            1'b0,
            32'h0000_0000
        );

        pass_test("SENSOR read routed correctly");


        // =====================================================================
        // TEST 8: VDP READ
        // =====================================================================
        //
        // VDP base:
        //
        //      0x0001_3000
        //
        // Level 1 verifies that the native transaction reaches the VDP slave.
        //
        // Complete VGA verification is outside this test.
        //
        // =====================================================================

        bus_read(
            VDP_BASE,
            3'd4,
            1'b0,
            32'h0000_0000
        );

        pass_test("VDP read routed correctly");


        // =====================================================================
        // TEST 9: TPU CONTROL WRITE
        // =====================================================================
        //
        // TPU register map currently begins at:
        //
        //      BASE + 0x00
        //
        // The test verifies:
        //
        //      CPU/native address
        //          |
        //          v
        //      TPU address decoder
        //          |
        //          v
        //      nn_axi_wrapper
        //
        // No TPU computation is expected from this Level-1 test.
        //
        // =====================================================================

        bus_write(
            TPU_BASE + 32'h0000,
            32'h0000_0001,
            4'b1111,
            3'd5
        );

        pass_test("TPU control write routed correctly");


        // =====================================================================
        // TEST 10: TPU STATUS READ
        // =====================================================================
        //
        // Status register:
        //
        //      BASE + 0x04
        //
        // Exact status value depends on accelerator state.
        //
        // Therefore routing/ready is checked.
        //
        // =====================================================================

        bus_read(
            TPU_BASE + 32'h0004,
            3'd5,
            1'b0,
            32'h0000_0000
        );

        pass_test("TPU status read routed correctly");


        // =====================================================================
        // TEST 11: TPU WEIGHT REGISTER WRITE
        // =====================================================================
        //
        // Weight0 low word:
        //
        //      BASE + 0x10
        //
        // This verifies that a real MMIO transaction reaches the TPU wrapper.
        //
        // =====================================================================

        bus_write(
            TPU_BASE + 32'h0010,
            32'h1122_3344,
            4'b1111,
            3'd5
        );

        pass_test("TPU weight0 low-word write routed correctly");


        // =====================================================================
        // TEST 12: TPU WEIGHT REGISTER HIGH WORD
        // =====================================================================

        bus_write(
            TPU_BASE + 32'h0014,
            32'h5566_7788,
            4'b1111,
            3'd5
        );

        pass_test("TPU weight0 high-word write routed correctly");


        // =====================================================================
        // TEST 13: TPU INPUT REGISTER
        // =====================================================================

        bus_write(
            TPU_BASE + 32'h0038,
            32'hDEAD_BEEF,
            4'b1111,
            3'd5
        );

        pass_test("TPU input0 low-word write routed correctly");


        // =====================================================================
        // TEST 14: INVALID ADDRESS
        // =====================================================================
        //
        // 0x0001_5000 is outside every currently implemented peripheral window.
        //
        // =====================================================================

        invalid_read(
            32'h0001_5000
        );


        // =====================================================================
        // FINAL GUARD BAND
        // =====================================================================

        repeat (FINAL_GUARD_CYCLES)
            @(posedge clk);


        // =====================================================================
        // FINAL REPORT
        // =====================================================================

        $display("");
        $display("============================================================");
        $display("LEVEL-1 TEST SUMMARY");
        $display("============================================================");

        $display(
            "Total checks : %0d",
            total_tests
        );

        $display(
            "Passed       : %0d",
            passed_tests
        );

        $display(
            "Failed       : %0d",
            failed_tests
        );

        $display("");


        if (
            (failed_tests == 0) &&
            (test_failed == 1'b0)
        ) begin

            $display("============================================================");
            $display("TB_CPU_SOC_RAM_TOP");
            $display("LEVEL-1 RESULT : ALL TESTS PASSED");
            $display("============================================================");

        end
        else begin

            $display("============================================================");
            $display("TB_CPU_SOC_RAM_TOP");
            $display("LEVEL-1 RESULT : FAILED");
            $display("============================================================");

        end


        $display("");

        $finish;

    end


    // =========================================================================
    // 20. GLOBAL SIMULATION WATCHDOG
    // =========================================================================
    //
    // Independent safety net.
    //
    // If a task becomes stuck because of an RTL deadlock, simulation cannot
    // continue indefinitely.
    //
    // =========================================================================

    initial begin : global_watchdog

        #10000;

        $display("");
        $display("============================================================");
        $display("GLOBAL TESTBENCH TIMEOUT");
        $display("============================================================");
        $display(
            "Simulation exceeded 10 us."
        );
        $display("");

        test_failed = 1'b1;

        $finish;

    end


endmodule