`timescale 1ns/1ps

// =============================================================================
// tb_sensor_status_native.v
//
// Self-checking testbench for sensor_status_native_slave
//
// Native PicoRV32 memory interface:
//
//   READ:
//       mem_valid = 1
//       mem_wstrb = 4'b0000
//
//   WRITE:
//       mem_valid = 1
//       mem_wstrb != 4'b0000
//
// Response:
//
//   Cycle N:
//       mem_valid = 1
//       mem_ready = 0
//
//   Cycle N+1:
//       mem_ready = 1
//       mem_rdata = response
//
// Native PicoRV32 bus has no SLVERR.
// Unmapped reads return 0 and complete normally.
// =============================================================================

module tb_power;

    // =========================================================================
    // Clock / reset
    // =========================================================================
    reg clk;
    reg resetn;

    // =========================================================================
    // PicoRV32 native memory interface
    // =========================================================================
    reg         mem_valid;
    reg         mem_instr;
    wire        mem_ready;

    reg  [11:0] mem_addr;
    reg  [31:0] mem_wdata;
    reg  [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;

    // =========================================================================
    // Sensor inputs
    // =========================================================================
    reg [7:0]  battery_percent;
    reg [15:0] battery_voltage;
    reg [15:0] temperature;
    reg        sensor_valid;

    // =========================================================================
    // Test variables
    // =========================================================================
    integer errors;
    reg [31:0] rd_data;

    // =========================================================================
    // DUT
    // =========================================================================
    sensor_status_native_slave dut (
        .clk                   (clk),
        .resetn                (resetn),

        .mem_valid             (mem_valid),
        .mem_instr             (mem_instr),
        .mem_ready             (mem_ready),
        .mem_addr              (mem_addr),
        .mem_wdata             (mem_wdata),
        .mem_wstrb             (mem_wstrb),
        .mem_rdata             (mem_rdata),

        .battery_percent_i     (battery_percent),
        .battery_voltage_mv_i  (battery_voltage),
        .temperature_tenthsC_i (temperature),
        .sensor_valid_i        (sensor_valid)
    );

    // =========================================================================
    // Clock
    // =========================================================================
    always #5 clk = ~clk;


    // =========================================================================
    // Native READ task
    //
    // The request is driven before a rising edge.
    //
    // Request cycle:
    //     mem_valid = 1
    //     mem_ready = 0
    //
    // Response cycle:
    //     mem_ready = 1
    //     mem_rdata = valid response
    //
    // #1 is intentionally used after the clock edge so that nonblocking
    // assignments in the DUT have updated before the testbench samples signals.
    // =========================================================================
    task native_read;
        input  [11:0] addr;
        output [31:0] data;

        begin

            // -------------------------------------------------------------
            // Drive request
            // -------------------------------------------------------------
            @(negedge clk);

            mem_addr  = addr;
            mem_wdata = 32'h00000000;
            mem_wstrb = 4'b0000;
            mem_valid = 1'b1;

            // -------------------------------------------------------------
            // Request cycle
            // -------------------------------------------------------------
            @(posedge clk);
            #1;

            if (mem_ready !== 1'b0) begin
                $display("FAIL: mem_ready = %b on request cycle (expected 0, addr=%03h)",
                         mem_ready, addr);
                errors = errors + 1;
            end
            else begin
                $display("PASS: mem_ready low when mem_valid is first asserted");
            end

            // -------------------------------------------------------------
            // Deassert request
            // -------------------------------------------------------------
            @(negedge clk);
            mem_valid = 1'b0;

            // -------------------------------------------------------------
            // Response cycle
            // -------------------------------------------------------------
            @(posedge clk);
            #1;

            if (mem_ready !== 1'b1) begin
                $display("FAIL: mem_ready = %b, expected 1 for addr=%03h",
                         mem_ready, addr);
                errors = errors + 1;
            end
            else begin
                $display("PASS: mem_ready asserted one cycle after mem_valid");
            end

            // Capture response after DUT NBA update
            data = mem_rdata;

            // Return bus to idle
            @(negedge clk);

            mem_addr  = 12'h000;
            mem_wdata = 32'h00000000;
            mem_wstrb = 4'b0000;

        end
    endtask


    // =========================================================================
    // Native WRITE task
    //
    // Sensor registers are read-only.
    //
    // Writes must:
    //   - complete normally
    //   - assert mem_ready one cycle later
    //   - not modify the sensor registers
    // =========================================================================
    task native_write;
        input [11:0] addr;
        input [31:0] data;
        input [3:0]  strb;

        begin

            // -------------------------------------------------------------
            // Drive write request
            // -------------------------------------------------------------
            @(negedge clk);

            mem_addr  = addr;
            mem_wdata = data;
            mem_wstrb = strb;
            mem_valid = 1'b1;

            // -------------------------------------------------------------
            // Request cycle
            // -------------------------------------------------------------
            @(posedge clk);
            #1;

            if (mem_ready !== 1'b0) begin
                $display("FAIL: mem_ready = %b during write request (expected 0)",
                         mem_ready);
                errors = errors + 1;
            end

            // -------------------------------------------------------------
            // Deassert request
            // -------------------------------------------------------------
            @(negedge clk);
            mem_valid = 1'b0;

            // -------------------------------------------------------------
            // Response cycle
            // -------------------------------------------------------------
            @(posedge clk);
            #1;

            if (mem_ready !== 1'b1) begin
                $display("FAIL: write mem_ready = %b, expected 1",
                         mem_ready);
                errors = errors + 1;
            end
            else begin
                $display("PASS: RO write accepted and completed");
            end

            // Return bus to idle
            @(negedge clk);

            mem_addr  = 12'h000;
            mem_wdata = 32'h00000000;
            mem_wstrb = 4'b0000;

        end
    endtask


    // =========================================================================
    // Main test
    // =========================================================================
    initial begin

        // ---------------------------------------------------------------------
        // Initial values
        // ---------------------------------------------------------------------
        clk = 1'b0;

        resetn = 1'b0;

        mem_valid = 1'b0;
        mem_instr = 1'b0;
        mem_addr  = 12'h000;
        mem_wdata = 32'h00000000;
        mem_wstrb = 4'b0000;

        battery_percent = 8'd67;
        battery_voltage = 16'd3700;
        temperature     = 16'sd235;
        sensor_valid    = 1'b1;

        errors = 0;
        rd_data = 32'h00000000;


        // =====================================================================
        // RESET
        // =====================================================================

        repeat (4) @(posedge clk);

        resetn = 1'b1;

        // Allow the 2-FF synchronizers to settle.
        repeat (4) @(posedge clk);


        // =====================================================================
        // BATTERY_PERCENT
        // =====================================================================

        native_read(12'h000, rd_data);

        if (rd_data === 32'h00000043) begin
            $display("PASS: BATTERY_PERCENT = %0d", rd_data);
        end
        else begin
            $display("FAIL: BATTERY_PERCENT = %0d (expected 67)",
                     rd_data);
            errors = errors + 1;
        end


        // =====================================================================
        // BATTERY_VOLTAGE
        // =====================================================================

        native_read(12'h004, rd_data);

        if (rd_data === 32'h00000E74) begin
            $display("PASS: BATTERY_VOLTAGE = %0d mV", rd_data);
        end
        else begin
            $display("FAIL: BATTERY_VOLTAGE = %0d (expected 3700)",
                     rd_data);
            errors = errors + 1;
        end


        // =====================================================================
        // TEMPERATURE
        // =====================================================================

        native_read(12'h008, rd_data);

        if (rd_data === 32'h000000EB) begin
            $display("PASS: TEMPERATURE = %0d tenths C", rd_data);
        end
        else begin
            $display("FAIL: TEMPERATURE = %0d (expected 235)",
                     rd_data);
            errors = errors + 1;
        end


        // =====================================================================
        // SENSOR_STATUS
        //
        // sensor_valid = 1
        // battery_low  = 0 because 67 > 15
        // temp_alarm   = 0 because 23.5 C < 80.0 C
        //
        // bit2 = temp_alarm  = 0
        // bit1 = battery_low = 0
        // bit0 = sensor_valid = 1
        //
        // Expected = 32'h00000001
        // =====================================================================

        native_read(12'h00C, rd_data);

        if (rd_data === 32'h00000001) begin
            $display("PASS: SENSOR_STATUS = %08h (valid=1, batt_low=0, temp_alarm=0)",
                     rd_data);
        end
        else begin
            $display("FAIL: SENSOR_STATUS = %08h (expected 00000001)",
            rd_data);
            errors = errors + 1;
        end


        // =====================================================================
        // LOW-BATTERY ALARM
        //
        // Change battery percentage from 67% to 10%.
        //
        // 10 <= 15
        // Therefore battery_low = 1.
        //
        // sensor_valid = 1
        // battery_low  = 1
        // temp_alarm   = 0
        //
        // Expected = 32'h00000003
        // =====================================================================

        battery_percent = 8'd10;

        // Allow the 2-FF synchronizer to capture the new value.
        repeat (4) @(posedge clk);

        native_read(12'h00C, rd_data);

        if (rd_data === 32'h00000003) begin
            $display("PASS: SENSOR_STATUS = %08h (valid=1, batt_low=1, temp_alarm=0)",
                     rd_data);
        end
        else begin
            $display("FAIL: SENSOR_STATUS = %08h (expected 00000003)",
                     rd_data);
            errors = errors + 1;
        end


        // =====================================================================
        // TEMPERATURE ALARM
        //
        // 801 tenths C = 80.1 C.
        //
        // Alarm condition:
        //     temperature > 800
        //
        // Therefore:
        //     temp_alarm = 1
        //
        // battery_low remains 1.
        // sensor_valid remains 1.
        //
        // Expected:
        //     bit2 = 1
        //     bit1 = 1
        //     bit0 = 1
        //
        //     32'h00000007
        // =====================================================================

        temperature = 16'sd801;

        // Allow the 2-FF synchronizer to capture the new value.
        repeat (4) @(posedge clk);

        native_read(12'h00C, rd_data);

        if (rd_data === 32'h00000007) begin
            $display("PASS: SENSOR_STATUS = %08h (valid=1, batt_low=1, temp_alarm=1)",
                     rd_data);
        end
        else begin
            $display("FAIL: SENSOR_STATUS = %08h (expected 00000007)",
                     rd_data);
            errors = errors + 1;
        end


        // =====================================================================
        // WRITE TO READ-ONLY REGISTER
        //
        // BATTERY_PERCENT is RO.
        //
        // Write 0xFFFFFFFF.
        // The write must be accepted but discarded.
        // =====================================================================

        native_write(
            12'h000,
            32'hFFFF_FFFF,
            4'hF
        );


        // Verify that BATTERY_PERCENT is still 10.
        native_read(12'h000, rd_data);

        if (rd_data === 32'h0000000A) begin
            $display("PASS: BATTERY_PERCENT unchanged by RO write (=%0d)",
                     rd_data);
        end
        else begin
            $display("FAIL: BATTERY_PERCENT changed to %0d (expected 10)",
                     rd_data);
            errors = errors + 1;
        end


        // =====================================================================
        // UNMAPPED ADDRESS
        //
        // Native PicoRV32 bus has no SLVERR.
        //
        // Expected:
        //     mem_ready = 1
        //     mem_rdata = 0
        // =====================================================================

        native_read(12'h0F0, rd_data);

        if (rd_data === 32'h00000000) begin
            $display("PASS: unmapped offset 0x0F0 returns 0");
        end
        else begin
            $display("FAIL: unmapped offset 0x0F0 returned %08h (expected 00000000)",
                     rd_data);
            errors = errors + 1;
        end


        // =====================================================================
        // FINAL RESULT
        // =====================================================================

        if (errors == 0) begin
            $display("==== TB_SENSOR_STATUS_NATIVE: ALL TESTS PASSED ====");
        end
        else begin
            $display("==== TB_SENSOR_STATUS_NATIVE: %0d TEST(S) FAILED ====",
                     errors);
        end

        $finish;

    end

endmodule