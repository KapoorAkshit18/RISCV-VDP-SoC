`timescale 1ns/1ps

// =============================================================================
// tb_cpu_soc_ram_top.sv
//
// LEVEL-1 MANUAL PERIPHERAL / INTEGRATION TESTBENCH
// =============================================================================
//
// PURPOSE
// -------
// This testbench verifies the committed cpu_soc_ram_top integration WITHOUT
// firmware.
//
// PicoRV32 is intentionally NOT used to generate transactions in this test.
// Instead, the testbench temporarily forces the native master-side bus signals
// inside cpu_soc_ram_top:
//
//     dut.m_valid
//     dut.m_write
//     dut.m_addr
//     dut.m_wdata
//     dut.m_strb
//
// This bypasses:
//
//     PicoRV32 -> CPU Bus Adapter
//
// while preserving the REAL committed:
//
//     soc_mem_interconnect
//         |
//         +--> RAM
//         +--> GPIO
//         +--> RF
//         +--> SENSOR
//         +--> VDP
//         +--> TPU
//
// Therefore this is a PERIPHERAL / INTERCONNECT INTEGRATION TEST,
// not a CPU/firmware test.
//
// IMPORTANT
// ---------
// Firmware is deliberately NOT loaded here.
//
// No $readmemh() is required.
//
// =============================================================================
// TEST LEVEL
// =============================================================================
//
// Level 1:
//
//   Manual native-bus transaction
//       |
//       v
//   cpu_soc_ram_top
//       |
//       v
//   soc_mem_interconnect
//       |
//       +--> selected peripheral
//
// Tested here:
//
//   1. Reset
//   2. RAM read/write
//   3. RAM byte strobes
//   4. GPIO DATA_OUT
//   5. GPIO DIR
//   6. GPIO DATA_IN
//   7. RF telemetry
//   8. RF control
//   9. Sensor telemetry
//  10. VDP control/color/status
//  11. TPU register bank
//  12. TPU seven-payload configuration
//  13. TPU status
//  14. Invalid/unmapped address
//
// =============================================================================
// SYSTEM ADDRESS MAP
// =============================================================================
//
//   0x0000_0000 - 0x0000_FFFF : RAM
//   0x0001_0000 - 0x0001_0FFF : GPIO
//   0x0001_1000 - 0x0001_1FFF : RF
//   0x0001_2000 - 0x0001_2FFF : SENSOR
//   0x0001_3000 - 0x0001_3FFF : VDP
//   0x0001_4000 - 0x0001_4FFF : TPU / NN
//
// Peripheral addresses below are SYSTEM addresses.
// The interconnect converts them to 12-bit local addresses.
//
// =============================================================================
// NATIVE BUS CONVENTION
// =============================================================================
//
//   m_valid = 1       -> transaction is valid
//   m_write = 1       -> write transaction
//   m_write = 0       -> read transaction
//   m_strb = 4'b0000  -> read
//   m_strb != 0       -> write
//
// =============================================================================


module tb_cpu_soc_ram_top;

    // =========================================================================
    // CLOCK PARAMETERS
    // =========================================================================

    localparam time CLK_PERIOD       = 10ns;   // 100 MHz system clock
    localparam time PIXEL_CLK_PERIOD = 40ns;   // 25 MHz pixel clock

    // =========================================================================
    // TEST PARAMETERS
    // =========================================================================

    localparam integer READY_TIMEOUT = 20;

    // =========================================================================
    // SYSTEM ADDRESS MAP
    // =========================================================================

    localparam [31:0] RAM_BASE    = 32'h0000_0000;
    localparam [31:0] RAM_LAST    = 32'h0000_FFFF;

    localparam [31:0] GPIO_BASE   = 32'h0001_0000;
    localparam [31:0] GPIO_LAST   = 32'h0001_0FFF;

    localparam [31:0] RF_BASE     = 32'h0001_1000;
    localparam [31:0] RF_LAST     = 32'h0001_1FFF;

    localparam [31:0] SENSOR_BASE = 32'h0001_2000;
    localparam [31:0] SENSOR_LAST = 32'h0001_2FFF;

    localparam [31:0] VDP_BASE    = 32'h0001_3000;
    localparam [31:0] VDP_LAST    = 32'h0001_3FFF;

    localparam [31:0] TPU_BASE    = 32'h0001_4000;
    localparam [31:0] TPU_LAST    = 32'h0001_4FFF;

    // =========================================================================
    // GPIO LOCAL REGISTER MAP
    // =========================================================================

    localparam [11:0] GPIO_DATA_OUT = 12'h000;
    localparam [11:0] GPIO_DATA_IN  = 12'h004;
    localparam [11:0] GPIO_DIR      = 12'h008;
    localparam [11:0] GPIO_STATUS   = 12'h00C;

    // =========================================================================
    // RF LOCAL REGISTER MAP
    // =========================================================================

    localparam [11:0] RF_RSSI       = 12'h000;
    localparam [11:0] RF_LINK_STAT  = 12'h004;
    localparam [11:0] RF_CONTROL    = 12'h008;
    localparam [11:0] RF_ID         = 12'h00C;

    // =========================================================================
    // SENSOR LOCAL REGISTER MAP
    // =========================================================================

    localparam [11:0] SENSOR_BATT_PCT  = 12'h000;
    localparam [11:0] SENSOR_BATT_VOLT = 12'h004;
    localparam [11:0] SENSOR_TEMP      = 12'h008;
    localparam [11:0] SENSOR_STATUS    = 12'h00C;

    // =========================================================================
    // VDP LOCAL REGISTER MAP
    // =========================================================================

    localparam [11:0] VDP_CTRL   = 12'h000;
    localparam [11:0] VDP_STATUS = 12'h004;
    localparam [11:0] VDP_HCOUNT = 12'h008;
    localparam [11:0] VDP_VCOUNT = 12'h00C;
    localparam [11:0] VDP_COLOR  = 12'h010;

    // =========================================================================
    // TPU LOCAL REGISTER MAP
    // =========================================================================

    localparam [11:0] TPU_CONTROL = 12'h000;
    localparam [11:0] TPU_STATUS  = 12'h004;

    localparam [11:0] TPU_WEIGHT0_L = 12'h010;
    localparam [11:0] TPU_WEIGHT0_H = 12'h014;

    localparam [11:0] TPU_WEIGHT1_L = 12'h018;
    localparam [11:0] TPU_WEIGHT1_H = 12'h01C;

    localparam [11:0] TPU_WEIGHT2_L = 12'h020;
    localparam [11:0] TPU_WEIGHT2_H = 12'h024;

    localparam [11:0] TPU_WEIGHT3_L = 12'h028;
    localparam [11:0] TPU_WEIGHT3_H = 12'h02C;

    localparam [11:0] TPU_WEIGHT4_L = 12'h030;
    localparam [11:0] TPU_WEIGHT4_H = 12'h034;

    localparam [11:0] TPU_INPUT0_L = 12'h038;
    localparam [11:0] TPU_INPUT0_H = 12'h03C;

    localparam [11:0] TPU_INPUT1_L = 12'h040;
    localparam [11:0] TPU_INPUT1_H = 12'h044;

    localparam [11:0] TPU_RESULT0_L = 12'h050;
    localparam [11:0] TPU_RESULT0_H = 12'h054;

    localparam [11:0] TPU_RESULT1_L = 12'h058;
    localparam [11:0] TPU_RESULT1_H = 12'h05C;

    // =========================================================================
    // Status Checking
    // =========================================================================
    reg success_status ;
    reg actual_status ;
    // =========================================================================
    // CLOCK / RESET
    // =========================================================================

    reg clk;
    reg pixel_clk;
    reg resetn;

    always #(CLK_PERIOD / 2)
        clk = ~clk;

    always #(PIXEL_CLK_PERIOD / 2)
        pixel_clk = ~pixel_clk;

    // =========================================================================
    // TOP-LEVEL INPUTS
    // =========================================================================

    reg [7:0]  battery_percent_i;
    reg [15:0] battery_voltage_mv_i;
    reg [15:0] temperature_tenthsC_i;
    reg        sensor_valid_i;

    reg [7:0]  rssi_dbm_i;
    reg        link_up_i;
    reg        link_error_i;
    reg        carrier_detect_i;

    reg [31:0] gpio_in;

    // =========================================================================
    // TOP-LEVEL OUTPUTS
    // =========================================================================

    wire        rf_enable_o;

    wire [31:0] gpio_out;
    wire [31:0] gpio_oe;

    wire hsync_o;
    wire vsync_o;

    wire [11:0] pixel_x_o;
    wire [11:0] pixel_y_o;

    wire [3:0] rgb_r_o;
    wire [3:0] rgb_g_o;
    wire [3:0] rgb_b_o;

    wire trap;

    // =========================================================================
    // DUT
    // =========================================================================

    cpu_soc_ram_top #(
        .ADDR_WIDTH     (32),
        .DATA_WIDTH     (32),
        .RAM_ADDR_WIDTH (16),
        .RAM_DEPTH      (16384), // 2^14 words = 64 KB
        .GPIO_WIDTH     (32)
    ) dut (
        .clk                   (clk),
        .resetn                (resetn),

        .battery_percent_i     (battery_percent_i),
        .battery_voltage_mv_i  (battery_voltage_mv_i),
        .temperature_tenthsC_i (temperature_tenthsC_i),
        .sensor_valid_i        (sensor_valid_i),

        .rssi_dbm_i            (rssi_dbm_i),
        .link_up_i             (link_up_i),
        .link_error_i          (link_error_i),
        .carrier_detect_i      (carrier_detect_i),

        .rf_enable_o           (rf_enable_o),

        .gpio_out              (gpio_out),
        .gpio_oe               (gpio_oe),
        .gpio_in               (gpio_in),

        .pixel_clk             (pixel_clk),

        .hsync_o               (hsync_o),
        .vsync_o               (vsync_o),

        .pixel_x_o             (pixel_x_o),
        .pixel_y_o             (pixel_y_o),

        .rgb_r_o               (rgb_r_o),
        .rgb_g_o               (rgb_g_o),
        .rgb_b_o               (rgb_b_o),

        .trap                  (trap)
    );

    // =========================================================================
    // TESTBENCH MASTER BUS
    //
    // These are intentionally separate TB signals.
    //
    // The actual DUT bus signals are driven using force/release in the
    // transaction tasks below.
    // =========================================================================

    reg        tb_m_valid;
    reg        tb_m_write;
    reg [31:0] tb_m_addr;
    reg [31:0] tb_m_wdata;
    reg [3:0]  tb_m_strb;

    // =========================================================================
    // TEST RESULT ACCOUNTING
    // =========================================================================

    integer pass_count;
    integer fail_count;
    integer test_count;

    // =========================================================================
    // HELPER TASK: PASS
    // =========================================================================

    task automatic test_pass;
        input [255:0] test_name;

        begin
            pass_count = pass_count + 1;
            test_count = test_count + 1;

            $display("------------------------------------------------------------");
            $display("[PASS] %0s", test_name);
            $display("------------------------------------------------------------");
        end
    endtask

    // =========================================================================
    // HELPER TASK: FAIL
    // =========================================================================

    task automatic test_fail;
        input [255:0] test_name;
        input [31:0]  expected;
        input [31:0]  actual;

        begin
            fail_count  = fail_count + 1;
            test_count = test_count + 1;

            $display("------------------------------------------------------------");
            $display("[FAIL] %0s", test_name);
            $display("       Expected : %08h", expected);
            $display("       Actual   : %08h", actual);
            $display("------------------------------------------------------------");
        end
    endtask

    // =========================================================================
    // LOW-LEVEL BUS DRIVE
    //
    // Keep all DUT m_* signals forced together.
    // This prevents stale values from the CPU adapter from interfering with
    // the manually generated transaction.
    // =========================================================================

    task automatic drive_bus;
        input        write_en;
        input [31:0] address;
        input [31:0] write_data;
        input [3:0]  byte_strobe;

        begin
            tb_m_valid = 1'b1;
            tb_m_write = write_en;
            tb_m_addr  = address;
            tb_m_wdata = write_data;
            tb_m_strb  = byte_strobe;

            force dut.m_valid = tb_m_valid;
            force dut.m_write = tb_m_write;
            force dut.m_addr  = tb_m_addr;
            force dut.m_wdata = tb_m_wdata;
            force dut.m_strb  = tb_m_strb;
        end
    endtask

    // =========================================================================
    // RELEASE BUS
    // =========================================================================

    task automatic release_bus;

        begin
            tb_m_valid = 1'b0;
            tb_m_write = 1'b0;
            tb_m_addr  = 32'h0000_0000;
            tb_m_wdata = 32'h0000_0000;
            tb_m_strb  = 4'b0000;

            force dut.m_valid = tb_m_valid;  // why
            force dut.m_write = tb_m_write;
            force dut.m_addr  = tb_m_addr;
            force dut.m_wdata = tb_m_wdata;
            force dut.m_strb  = tb_m_strb;

            #1;

            release dut.m_valid;
            release dut.m_write;
            release dut.m_addr;
            release dut.m_wdata;
            release dut.m_strb;
        end
    endtask

    // =========================================================================
    // WAIT FOR READY
    //
    // The individual peripherals are synchronous and provide registered
    // responses. The interconnect itself is combinational.
    //
    // This task therefore waits for the actual DUT m_ready signal rather than
    // assuming a fixed latency.
    // =========================================================================

    task automatic wait_ready;
        output integer success;

        integer timeout;

        begin
            success = 0;

            timeout = 0;

            while ((dut.m_ready !== 1'b1) &&
                   (timeout < READY_TIMEOUT)) begin

                @(posedge clk);
                timeout = timeout + 1;

            end

            if (dut.m_ready === 1'b1)
                success = 1;
            else
                success = 0;
        end
    endtask

    // =========================================================================
    // MANUAL WRITE TRANSACTION
    //
    // Returns:
    //
    //   success = 1 -> ready observed
    //   success = 0 -> timeout
    // =========================================================================

    task automatic bus_write32;
        input  [31:0] address;
        input  [31:0] data;
        input  [3:0]  strb;
        output integer success;

        begin

            drive_bus(
                1'b1,
                address,
                data,
                strb
            );

            // Give the combinational interconnect one delta cycle to decode.
            #1;

            wait_ready(success);

            if (success) begin
                // Allow the slave's registered write to complete.
                @(posedge clk);
            end

            release_bus();

            // Guard band between independent transactions.
            repeat (1)
                @(posedge clk);
        end
    endtask

    // =========================================================================
    // MANUAL READ TRANSACTION
    // =========================================================================

    task automatic bus_read32;
        input  [31:0] address;
        output [31:0] data;
        output integer success;

        begin

            drive_bus(
                1'b0,
                address,
                32'h0000_0000,
                4'b0000
            );

            #1;

            wait_ready(success);

            if (success)
                data = dut.m_rdata;
            else
                data = 32'hxxxx_xxxx;

            // Hold request until response edge has completed.
            @(posedge clk);

            release_bus();

            repeat (1)
                @(posedge clk);
        end
    endtask

    // =========================================================================
    // CHECK WRITE COMPLETION
    // =========================================================================

    task automatic check_write;
        input [255:0] test_name;
        input [31:0] address;
        input [31:0] data;
        input [3:0]  strb;

        integer success;

        begin

            bus_write32(
                address,
                data,
                strb,
                success
            );

            if (success)
                test_pass(test_name);
            else
                test_fail(
                    test_name,
                    32'h0000_0001,
                    32'h0000_0000
                );
        end
    endtask

    // =========================================================================
    // CHECK READ
    // =========================================================================

    task automatic check_read;
        input [255:0] test_name;
        input [31:0] address;
        input [31:0] expected;

        reg [31:0] actual;
        integer success;

        begin

            bus_read32(
                address,
                actual,
                success
            );

            if (!success) begin

                test_fail(
                    test_name,
                    expected,
                    32'hxxxx_xxxx
                );

            end
            else if (actual !== expected) begin

                test_fail(
                    test_name,
                    expected,
                    actual
                );

            end
            else begin

                test_pass(test_name);

            end
        end
    endtask

    // =========================================================================
    // TEST: RESET
    // =========================================================================

    task automatic test_reset;

        begin

            $display("");
            $display("============================================================");
            $display("TEST 1 : RESET");
            $display("============================================================");

            resetn = 1'b0;

            repeat (5)
                @(posedge clk);

            if (gpio_out === 32'h0000_0000 &&
                gpio_oe  === 32'h0000_0000 &&
                rf_enable_o === 1'b0) begin

                test_pass("Reset state");

            end
            else begin

                $display(
                    "[FAIL] Reset state: gpio_out=%08h gpio_oe=%08h rf_enable=%b",
                    gpio_out,
                    gpio_oe,
                    rf_enable_o
                );

                fail_count  = fail_count + 1;
                test_count = test_count + 1;

            end

            resetn = 1'b1;

            repeat (5)
                @(posedge clk);

        end
    endtask

    // =========================================================================
    // TEST: RAM
    // =========================================================================

    task automatic test_ram;

        begin

            $display("");
            $display("============================================================");
            $display("TEST 2 : RAM");
            $display("============================================================");

            // Full-word write.
            check_write(
                "RAM full-word write",
                RAM_BASE + 32'h0000_0040,
                32'hA5A5_5A5A,
                4'b1111
            );

            // Full-word read.
            check_read(
                "RAM full-word read",
                RAM_BASE + 32'h0000_0040,
                32'hA5A5_5A5A
            );

            // -----------------------------------------------------------------
            // Byte-strobe test.
            //
            // First create:
            //
            //   0x11223344
            //
            // Then modify only byte lane 1:
            //
            //   0x1122AA44
            // -----------------------------------------------------------------

            check_write(
                "RAM byte-strobe setup",
                RAM_BASE + 32'h0000_0044,
                32'h1122_3344,
                4'b1111
            );

            check_write(
                "RAM byte lane 1 write",
                RAM_BASE + 32'h0000_0044,
                32'h0000_AA00,
                4'b0010
            );

            check_read(
                "RAM byte-strobe preservation",
                RAM_BASE + 32'h0000_0044,
                32'h1122_AA44
            );

            // -----------------------------------------------------------------
            // Individual byte lane 0.
            // -----------------------------------------------------------------

            check_write(
                "RAM byte lane 0 write",
                RAM_BASE + 32'h0000_0048,
                32'h0000_00EF,
                4'b0001
            );

            check_read(
                "RAM byte lane 0 read",
                RAM_BASE + 32'h0000_0048,
                32'h0000_00EF
            );

        end
    endtask

    // =========================================================================
    // TEST: GPIO
    // =========================================================================

    task automatic test_gpio;

        reg [31:0] actual;
        integer success;

        begin

            $display("");
            $display("============================================================");
            $display("TEST 3 : GPIO");
            $display("============================================================");

            // Configure all GPIOs as outputs.
            check_write(
                "GPIO direction write",
                GPIO_BASE + GPIO_DIR,
                32'hFFFF_FFFF,
                4'b1111
            );

            check_read(
                "GPIO direction readback",
                GPIO_BASE + GPIO_DIR,
                32'hFFFF_FFFF
            );

            // Drive output pattern.
            check_write(
                "GPIO DATA_OUT write",
                GPIO_BASE + GPIO_DATA_OUT,
                32'hCAFE_BABE,
                4'b1111
            );

            // Verify output pin value.
            #1;

            if (gpio_out === 32'hCAFE_BABE)
                test_pass("GPIO output pins");
            else
                test_fail(
                    "GPIO output pins",
                    32'hCAFE_BABE,
                    gpio_out
                );

            // Verify DATA_OUT register.
            check_read(
                "GPIO DATA_OUT readback",
                GPIO_BASE + GPIO_DATA_OUT,
                32'hCAFE_BABE
            );

            // -----------------------------------------------------------------
            // GPIO input synchronizer test.
            //
            // gpio_in passes through a two-flop synchronizer in the GPIO slave.
            // -----------------------------------------------------------------

            gpio_in = 32'h1357_9BDF;

            repeat (3)
                @(posedge clk);

            bus_read32(
                GPIO_BASE + GPIO_DATA_IN,
                actual,
                success
            );

            if (success && actual === 32'h1357_9BDF)
                test_pass("GPIO DATA_IN synchronized read");
            else
                test_fail(
                    "GPIO DATA_IN synchronized read",
                    32'h1357_9BDF,
                    actual
                );

        end
    endtask

    // =========================================================================
    // TEST: RF
    // =========================================================================

    task automatic test_rf;

        begin

            $display("");
            $display("============================================================");
            $display("TEST 4 : RF TELEMETRY");
            $display("============================================================");

            // Drive external RF telemetry inputs.
            rssi_dbm_i       = 8'hD8;
            link_up_i        = 1'b1;
            link_error_i     = 1'b0;
            carrier_detect_i = 1'b1;

            // Allow the RF two-stage synchronizers to settle.
            repeat (3)
                @(posedge clk);

            // RSSI.
            check_read(
                "RF RSSI read",
                RF_BASE + RF_RSSI,
                32'h0000_00D8
            );

            // Link status:
            //
            // bit0 = link_up       = 1
            // bit1 = link_error    = 0
            // bit2 = carrier       = 1
            //
            // => 0b101 = 0x5
            //
            check_read(
                "RF link-status read",
                RF_BASE + RF_LINK_STAT,
                32'h0000_0005
            );

            // RF identification register.
            check_read(
                "RF identification",
                RF_BASE + RF_ID,
                32'h5246_5430
            );

            // RF enable.
            check_write(
                "RF enable write",
                RF_BASE + RF_CONTROL,
                32'h0000_0001,
                4'b0001
            );

            if (rf_enable_o === 1'b1)
                test_pass("RF enable output");
            else
                test_fail(
                    "RF enable output",
                    32'h0000_0001,
                    {31'd0, rf_enable_o}
                );

            check_read(
                "RF control readback",
                RF_BASE + RF_CONTROL,
                32'h0000_0001
            );

            // Disable again.
            check_write(
                "RF disable write",
                RF_BASE + RF_CONTROL,
                32'h0000_0000,
                4'b0001
            );

        end
    endtask

    // =========================================================================
    // TEST: SENSOR
    // =========================================================================

    task automatic test_sensor;

        begin

            $display("");
            $display("============================================================");
            $display("TEST 5 : SENSOR STATUS");
            $display("============================================================");

            // Values intentionally selected so no alarm is active.
            //
            // battery = 80%
            // voltage = 3700 mV
            // temperature = 250 tenths C = 25.0 C
            //
            battery_percent_i     = 8'd80;
            battery_voltage_mv_i  = 16'd3700;
            temperature_tenthsC_i = 16'sd250;
            sensor_valid_i        = 1'b1;

            // Two-stage synchronizers.
            repeat (3)
                @(posedge clk);

            check_read(
                "Sensor battery percentage",
                SENSOR_BASE + SENSOR_BATT_PCT,
                32'h0000_0050
            );

            check_read(
                "Sensor battery voltage",
                SENSOR_BASE + SENSOR_BATT_VOLT,
                32'h0000_0E74
            );

            check_read(
                "Sensor temperature",
                SENSOR_BASE + SENSOR_TEMP,
                32'h0000_00FA
            );

            // status:
            //
            // bit0 sensor_valid = 1
            // bit1 battery_low  = 0
            // bit2 temp_alarm   = 0
            //
            // => 0x1
            //
            check_read(
                "Sensor status",
                SENSOR_BASE + SENSOR_STATUS,
                32'h0000_0001
            );

            // -----------------------------------------------------------------
            // Battery-low threshold test.
            // Threshold is <= 15%.
            // -----------------------------------------------------------------

            battery_percent_i = 8'd10;

            repeat (3)
                @(posedge clk);

            check_read(
                "Sensor battery-low alarm",
                SENSOR_BASE + SENSOR_STATUS,
                32'h0000_0003
            );

            // Restore nominal value.
            battery_percent_i = 8'd80;

            repeat (3)
                @(posedge clk);

        end
    endtask

    // =========================================================================
    // TEST: VDP
    // =========================================================================

    task automatic test_vdp;

        reg [31:0] actual;
        integer success;

        begin

            $display("");
            $display("============================================================");
            $display("TEST 6 : VDP / VGA");
            $display("============================================================");

            // -----------------------------------------------------------------
            // Initial VDP control state should be disabled.
            // -----------------------------------------------------------------

            check_read(
                "VDP initial control",
                VDP_BASE + VDP_CTRL,
                32'h0000_0000
            );

            // -----------------------------------------------------------------
            // Enable display + pattern mode.
            //
            // bit0 = display enable
            // bit1 = pattern mode
            //
            // value = 3
            // -----------------------------------------------------------------

            check_write(
                "VDP enable + pattern mode",
                VDP_BASE + VDP_CTRL,
                32'h0000_0003,
                4'b0001
            );

            check_read(
                "VDP control readback",
                VDP_BASE + VDP_CTRL,
                32'h0000_0003
            );

            // -----------------------------------------------------------------
            // Program RGB888 color.
            //
            // R = 0x12
            // G = 0x34
            // B = 0x56
            //
            // RGB888 = 0x123456
            // -----------------------------------------------------------------

            check_write(
                "VDP color write",
                VDP_BASE + VDP_COLOR,
                32'h0012_3456,
                4'b0111
            );

            check_read(
                "VDP color readback",
                VDP_BASE + VDP_COLOR,
                32'h0012_3456
            );

            // -----------------------------------------------------------------
            // Read pixel counters.
            //
            // These are dynamic values, so the test checks validity rather
            // than requiring a fixed count.
            // -----------------------------------------------------------------

            bus_read32(
                VDP_BASE + VDP_HCOUNT,
                actual,
                success
            );

            if (success && actual[31:12] === 20'h00000)
                test_pass("VDP HCOUNT read");
            else
                test_fail(
                    "VDP HCOUNT read",
                    32'h0000_0000,
                    actual
                );

            bus_read32(
                VDP_BASE + VDP_VCOUNT,
                actual,
                success
            );

            if (success && actual[31:12] === 20'h00000)
                test_pass("VDP VCOUNT read");
            else
                test_fail(
                    "VDP VCOUNT read",
                    32'h0000_0000,
                    actual
                );

            // -----------------------------------------------------------------
            // VDP status should be a legal four-bit status value.
            // -----------------------------------------------------------------

            bus_read32(
                VDP_BASE + VDP_STATUS,
                actual,
                success
            );

            if (success && actual[31:4] === 28'h0000000)
                test_pass("VDP status read");
            else
                test_fail(
                    "VDP status read",
                    32'h0000_0000,
                    actual
                );

            // -----------------------------------------------------------------
            // Disable display.
            // -----------------------------------------------------------------

            check_write(
                "VDP display disable",
                VDP_BASE + VDP_CTRL,
                32'h0000_0000,
                4'b0001
            );

        end
    endtask

    // =========================================================================
    // TEST: TPU / NN REGISTER BANK
    // =========================================================================
    //
    // This test verifies the MMIO portion of the TPU integration:
    //
    //     native bus
    //         |
    //         v
    //     interconnect
    //         |
    //         v
    //     nn_axi_wrapper
    //
    // It verifies all seven 64-bit payload values:
    //
    //     weight0
    //     weight1
    //     weight2
    //     weight3
    //     weight4
    //     input0
    //     input1
    //
    // Each 64-bit value is written as two 32-bit native-bus transactions.
    //
    // This is intentionally separated from the full accelerator computation
    // test. Level-1 first proves MMIO/register integration.
    // =========================================================================

    task automatic test_tpu;

        begin

            $display("");
            $display("============================================================");
            $display("TEST 7 : TPU / NN MMIO INTEGRATION");
            $display("============================================================");

            // -----------------------------------------------------------------
            // Initial status.
            //
            // axis_busy = 0
            // axis_done = 0
            //
            // status = {30'd0, done, busy} = 0
            // -----------------------------------------------------------------

            check_read(
                "TPU initial status",
                TPU_BASE + TPU_STATUS,
                32'h0000_0000
            );

            // -----------------------------------------------------------------
            // WEIGHT 0
            // 64-bit value = 0x1122334455667788
            // -----------------------------------------------------------------

            check_write(
                "TPU weight0 low",
                TPU_BASE + TPU_WEIGHT0_L,
                32'h5566_7788,
                4'b1111
            );

            check_write(
                "TPU weight0 high",
                TPU_BASE + TPU_WEIGHT0_H,
                32'h1122_3344,
                4'b1111
            );

            check_read(
                "TPU weight0 low readback",
                TPU_BASE + TPU_WEIGHT0_L,
                32'h5566_7788
            );

            check_read(
                "TPU weight0 high readback",
                TPU_BASE + TPU_WEIGHT0_H,
                32'h1122_3344
            );

            // -----------------------------------------------------------------
            // WEIGHT 1
            // -----------------------------------------------------------------

            check_write(
                "TPU weight1 low",
                TPU_BASE + TPU_WEIGHT1_L,
                32'hDDEE_FF00,
                4'b1111
            );

            check_write(
                "TPU weight1 high",
                TPU_BASE + TPU_WEIGHT1_H,
                32'h99AA_BBCC,
                4'b1111
            );

            check_read(
                "TPU weight1 low readback",
                TPU_BASE + TPU_WEIGHT1_L,
                32'hDDEE_FF00
            );

            check_read(
                "TPU weight1 high readback",
                TPU_BASE + TPU_WEIGHT1_H,
                32'h99AA_BBCC
            );

            // -----------------------------------------------------------------
            // WEIGHT 2
            // -----------------------------------------------------------------

            check_write(
                "TPU weight2 low",
                TPU_BASE + TPU_WEIGHT2_L,
                32'h0102_0304,
                4'b1111
            );

            check_write(
                "TPU weight2 high",
                TPU_BASE + TPU_WEIGHT2_H,
                32'h0506_0708,
                4'b1111
            );

            check_read(
                "TPU weight2 low readback",
                TPU_BASE + TPU_WEIGHT2_L,
                32'h0102_0304
            );

            check_read(
                "TPU weight2 high readback",
                TPU_BASE + TPU_WEIGHT2_H,
                32'h0506_0708
            );

            // -----------------------------------------------------------------
            // WEIGHT 3
            // -----------------------------------------------------------------

            check_write(
                "TPU weight3 low",
                TPU_BASE + TPU_WEIGHT3_L,
                32'hA1A2_A3A4,
                4'b1111
            );

            check_write(
                "TPU weight3 high",
                TPU_BASE + TPU_WEIGHT3_H,
                32'hB1B2_B3B4,
                4'b1111
            );

            check_read(
                "TPU weight3 low readback",
                TPU_BASE + TPU_WEIGHT3_L,
                32'hA1A2_A3A4
            );

            check_read(
                "TPU weight3 high readback",
                TPU_BASE + TPU_WEIGHT3_H,
                32'hB1B2_B3B4
            );

            // -----------------------------------------------------------------
            // WEIGHT 4
            // -----------------------------------------------------------------

            check_write(
                "TPU weight4 low",
                TPU_BASE + TPU_WEIGHT4_L,
                32'h1234_5678,
                4'b1111
            );

            check_write(
                "TPU weight4 high",
                TPU_BASE + TPU_WEIGHT4_H,
                32'h9ABC_DEF0,
                4'b1111
            );

            check_read(
                "TPU weight4 low readback",
                TPU_BASE + TPU_WEIGHT4_L,
                32'h1234_5678
            );

            check_read(
                "TPU weight4 high readback",
                TPU_BASE + TPU_WEIGHT4_H,
                32'h9ABC_DEF0
            );

            // -----------------------------------------------------------------
            // INPUT 0
            // -----------------------------------------------------------------

            check_write(
                "TPU input0 low",
                TPU_BASE + TPU_INPUT0_L,
                32'hCAFE_BABE,
                4'b1111
            );

            check_write(
                "TPU input0 high",
                TPU_BASE + TPU_INPUT0_H,
                32'hDEAD_BEEF,
                4'b1111
            );

            check_read(
                "TPU input0 low readback",
                TPU_BASE + TPU_INPUT0_L,
                32'hCAFE_BABE
            );

            check_read(
                "TPU input0 high readback",
                TPU_BASE + TPU_INPUT0_H,
                32'hDEAD_BEEF
            );

            // -----------------------------------------------------------------
            // INPUT 1
            // -----------------------------------------------------------------

            check_write(
                "TPU input1 low",
                TPU_BASE + TPU_INPUT1_L,
                32'h0BAD_F00D,
                4'b1111
            );

            check_write(
                "TPU input1 high",
                TPU_BASE + TPU_INPUT1_H,
                32'hFACE_CAFE,
                4'b1111
            );

            check_read(
                "TPU input1 low readback",
                TPU_BASE + TPU_INPUT1_L,
                32'h0BAD_F00D
            );

            check_read(
                "TPU input1 high readback",
                TPU_BASE + TPU_INPUT1_H,
                32'hFACE_CAFE
            );

            // -----------------------------------------------------------------
            // RESULT REGISTERS
            //
            // These are read-only from the MMIO wrapper perspective and should
            // initially be zero unless the accelerator has already produced
            // results.
            // -----------------------------------------------------------------

            check_read(
                "TPU result0 low initial",
                TPU_BASE + TPU_RESULT0_L,
                32'h0000_0000
            );

            check_read(
                "TPU result0 high initial",
                TPU_BASE + TPU_RESULT0_H,
                32'h0000_0000
            );

            check_read(
                "TPU result1 low initial",
                TPU_BASE + TPU_RESULT1_L,
                32'h0000_0000
            );

            check_read(
                "TPU result1 high initial",
                TPU_BASE + TPU_RESULT1_H,
                32'h0000_0000
            );

            // -----------------------------------------------------------------
            // START command.
            //
            // CONTROL bit 0 = START.
            //
            // The wrapper only accepts START when axis_busy = 0.
            // -----------------------------------------------------------------

            check_write(
                "TPU START command",
                TPU_BASE + TPU_CONTROL,
                32'h0000_0001,
                4'b0001
            );

            // Give the AXI-stream master / accelerator time to react.
            repeat (5)
                @(posedge clk);

            // Read status after START.
            //
            // We intentionally do not require BUSY to remain high here because
            // the accelerator may complete quickly.
            //
            // The important Level-1 requirement is that the START MMIO write
            // reaches the wrapper and is accepted.
            bus_read32(
                TPU_BASE + TPU_STATUS,
                actual_status,
                success_status
            );

            if (success_status)
                test_pass("TPU status after START");
            else
                test_fail(
                    "TPU status after START",
                    32'h0000_0000,
                    32'hxxxx_xxxx
                );

        end
    endtask

    // =========================================================================
    // TEST: TPU BYTE STROBES
    // =========================================================================
    //
    // This specifically verifies that the 32-bit native bus can modify only
    // selected bytes of a 64-bit TPU register.
    // =========================================================================

    task automatic test_tpu_byte_strobes;

        reg [31:0] actual;
        integer success;

        begin

            $display("");
            $display("============================================================");
            $display("TEST 8 : TPU BYTE STROBES");
            $display("============================================================");

            // Establish a known low word.
            check_write(
                "TPU byte-strobe setup",
                TPU_BASE + TPU_WEIGHT0_L,
                32'h1122_3344,
                4'b1111
            );

            // Modify only byte 0.
            check_write(
                "TPU byte lane 0 modification",
                TPU_BASE + TPU_WEIGHT0_L,
                32'h0000_00AA,
                4'b0001
            );

            // Expected = 0x112233AA.
            bus_read32(
                TPU_BASE + TPU_WEIGHT0_L,
                actual,
                success
            );

            if (success && actual === 32'h1122_33AA)
                test_pass("TPU byte lane 0 preservation");
            else
                test_fail(
                    "TPU byte lane 0 preservation",
                    32'h1122_33AA,
                    actual
                );

            // Modify only byte 3.
            check_write(
                "TPU byte lane 3 modification",
                TPU_BASE + TPU_WEIGHT0_L,
                32'hBB00_0000,
                4'b1000
            );

            // Expected = 0xBB2233AA.
            check_read(
                "TPU byte lane 3 preservation",
                TPU_BASE + TPU_WEIGHT0_L,
                32'hBB22_33AA
            );

        end
    endtask

    // =========================================================================
    // TEST: INVALID ADDRESS
    // =========================================================================
    //
    // The committed interconnect explicitly completes unmapped accesses with:
    //
    //     m_ready = 1
    //     m_rdata = 0
    //
    // There is no AXI-style SLVERR on this native bus.
    // =========================================================================

    task automatic test_invalid_address;

        begin

            $display("");
            $display("============================================================");
            $display("TEST 9 : INVALID / UNMAPPED ADDRESS");
            $display("============================================================");

            check_read(
                "Unmapped address read",
                32'h0002_0000,
                32'h0000_0000
            );

            check_write(
                "Unmapped address write",
                32'h0002_0000,
                32'hDEAD_BEEF,
                4'b1111
            );

        end
    endtask

    // =========================================================================
    // FINAL SUMMARY
    // =========================================================================

    task automatic print_summary;

        begin

            $display("");
            $display("");
            $display("================================================================");
            $display("                LEVEL-1 SOC INTEGRATION SUMMARY");
            $display("================================================================");
            $display("");
            $display("Total checks : %0d", test_count);
            $display("PASS         : %0d", pass_count);
            $display("FAIL         : %0d", fail_count);
            $display("");

            if (fail_count == 0) begin

                $display("================================================================");
                $display("                 ALL LEVEL-1 TESTS PASSED");
                $display("================================================================");

            end
            else begin

                $display("================================================================");
                $display("                 LEVEL-1 TEST FAILED");
                $display("================================================================");

            end

            $display("");
            $display("NOTE:");
            $display("This testbench does NOT load firmware.");
            $display("CPU instruction execution is intentionally bypassed.");
            $display("The real SoC interconnect and peripheral RTL were exercised.");
            $display("");

        end
    endtask

    // =========================================================================
    // MAIN TEST SEQUENCE
    // =========================================================================

    initial begin

        // ---------------------------------------------------------------------
        // Initial values
        // ---------------------------------------------------------------------

        clk = 1'b0;
        pixel_clk = 1'b0;

        resetn = 1'b0;

        battery_percent_i     = 8'd0;
        battery_voltage_mv_i  = 16'd0;
        temperature_tenthsC_i = 16'd0;
        sensor_valid_i        = 1'b0;

        rssi_dbm_i       = 8'd0;
        link_up_i        = 1'b0;
        link_error_i     = 1'b0;
        carrier_detect_i = 1'b0;

        gpio_in = 32'h0000_0000;

        tb_m_valid = 1'b0;
        tb_m_write = 1'b0;
        tb_m_addr  = 32'h0000_0000;
        tb_m_wdata = 32'h0000_0000;
        tb_m_strb  = 4'b0000;

        pass_count = 0;
        fail_count = 0;
        test_count = 0;

        // ---------------------------------------------------------------------
        // Initial bus forcing.
        //
        // This ensures the CPU adapter cannot create an accidental transaction
        // while reset is being released.
        // ---------------------------------------------------------------------

        force dut.m_valid = 1'b0;
        force dut.m_write = 1'b0;
        force dut.m_addr  = 32'h0000_0000;
        force dut.m_wdata = 32'h0000_0000;
        force dut.m_strb  = 4'b0000;

        // ---------------------------------------------------------------------
        // Reset test.
        // ---------------------------------------------------------------------

        test_reset();

        // ---------------------------------------------------------------------
        // Release only after reset has completed.
        // ---------------------------------------------------------------------

        release dut.m_valid;
        release dut.m_write;
        release dut.m_addr;
        release dut.m_wdata;
        release dut.m_strb;

        // Guard band.
        repeat (2)
            @(posedge clk);

        // ---------------------------------------------------------------------
        // Peripheral tests.
        // ---------------------------------------------------------------------

        test_ram();

        test_gpio();

        test_rf();

        test_sensor();

        test_vdp();

        test_tpu();

        test_tpu_byte_strobes();

        test_invalid_address();

        // ---------------------------------------------------------------------
        // Final summary.
        // ---------------------------------------------------------------------

        print_summary();

        // ---------------------------------------------------------------------
        // End simulation.
        // ---------------------------------------------------------------------

        if (fail_count == 0)
            $finish;
        else
            $fatal(1, "LEVEL-1 TB FAILED: %0d failures", fail_count);

    end

    // =========================================================================
    // GLOBAL SAFETY TIMEOUT
    //
    // Prevents a hung simulation if a slave never asserts ready.
    // =========================================================================

    initial begin

        #1_000_000;

        $fatal(
            1,
            "GLOBAL TIMEOUT: Level-1 testbench exceeded simulation limit."
        );

    end

    // =========================================================================
    // WAVEFORM DUMP
    // =========================================================================

    initial begin

        $dumpfile("waveform_phase_5_wo_firmw.vcd");
        $dumpvars(0, tb_cpu_soc_ram_top);

    end

endmodule
