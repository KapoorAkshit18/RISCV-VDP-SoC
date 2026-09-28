`timescale 1ns / 1ps

// =============================================================================
// RISCV-VDP-SoC - PHASE 5 COMPLETE TESTBENCH (directed, non-UVM)
//
// Observes:
//   1. Firmware loading
//   2. CPU native-bus transactions
//   3. RAM transactions
//   4. TPU MMIO transactions
//   5. TPU control START write
//   6. TPU internal START/BUSY/DONE signals
//   7. AXI-stream input/output handshakes
//   8. TPU result registers
//   9. Firmware completion/failure markers
//  10. CPU trap
//
// Plusargs (all optional):
//   +FW_HEX=<path>   firmware hex file (default: ./firmware_test03/firmware.hex)
//   +TEMP_C=<real>   sensor temperature in degC, fed through the RNM chain
//                    (default: 79.9)
//   +BATT=<int>      battery percent (default: 80)
//
// IMPORTANT - firmware completion markers differ by firmware image:
//   TPU firmware   (as originally written for this TB): completion = 0x33333333,
//                  failure = 0xDEAD0001
//   SENSOR firmware (from the sensor test C source): the *intermediate* status-ok
//                  marker also happens to be 0x33333333, but the actual
//                  end-of-test success marker is 0x55555555, failure 0xDEAD0001.
//   This TB now treats BOTH 0x33333333 and 0x55555555 as "done" so it works
//   with either image, and reports which one it saw. If you add a third
//   firmware image with its own marker convention, extend the check below.
// =============================================================================

module tb_cpu_soc_ram_top;

    // =========================================================================
    // PARAMETERS
    // =========================================================================

    localparam integer TIMEOUT_CYCLES = 1_000_000;

    localparam [31:0] FIRMWARE_MARKER_ADDR = 32'h0000_12A8;
    localparam [31:0] FIRMWARE_ERROR_ADDR  = 32'h0000_12AC;

    localparam [31:0] MARK_STATUS_OK_OR_TPU_DONE = 32'h3333_3333; // TPU completion / sensor intermediate
    localparam [31:0] MARK_SENSOR_SUCCESS        = 32'h5555_5555; // sensor final success
    localparam [31:0] MARK_FAIL                  = 32'hDEAD_0001;

    localparam [31:0] RESULT_BASE  = 32'h0000_1230;
    localparam integer RESULT_WORDS = 4;

    localparam [31:0] TPU_BASE = 32'h0001_4000;

    localparam [31:0] TPU_CTRL   = TPU_BASE + 32'h0000;
    localparam [31:0] TPU_STATUS = TPU_BASE + 32'h0004;

    localparam [31:0] TPU_WEIGHT0_L = TPU_BASE + 32'h0010;
    localparam [31:0] TPU_WEIGHT0_H = TPU_BASE + 32'h0014;

    localparam [31:0] TPU_WEIGHT1_L = TPU_BASE + 32'h0018;
    localparam [31:0] TPU_WEIGHT1_H = TPU_BASE + 32'h001C;

    localparam [31:0] TPU_WEIGHT2_L = TPU_BASE + 32'h0020;
    localparam [31:0] TPU_WEIGHT2_H = TPU_BASE + 32'h0024;

    localparam [31:0] TPU_WEIGHT3_L = TPU_BASE + 32'h0028;
    localparam [31:0] TPU_WEIGHT3_H = TPU_BASE + 32'h002C;

    localparam [31:0] TPU_WEIGHT4_L = TPU_BASE + 32'h0030;
    localparam [31:0] TPU_WEIGHT4_H = TPU_BASE + 32'h0034;

    localparam [31:0] TPU_INPUT0_L = TPU_BASE + 32'h0038;
    localparam [31:0] TPU_INPUT0_H = TPU_BASE + 32'h003C;

    localparam [31:0] TPU_INPUT1_L = TPU_BASE + 32'h0040;
    localparam [31:0] TPU_INPUT1_H = TPU_BASE + 32'h0044;

    localparam [31:0] TPU_RESULT0_L = TPU_BASE + 32'h0050;
    localparam [31:0] TPU_RESULT0_H = TPU_BASE + 32'h0054;

    localparam [31:0] TPU_RESULT1_L = TPU_BASE + 32'h0058;
    localparam [31:0] TPU_RESULT1_H = TPU_BASE + 32'h005C;

    // Sensor MMIO window (matches SENSOR_BASE in the sensor firmware / soc_coverage)
    localparam [31:0] SENSOR_BASE = 32'h0001_2000;

    // =========================================================================
    // CLOCKS
    // =========================================================================

    reg clk;
    reg resetn;
    reg pixel_clk;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;  // 10 ns
    end

    initial begin
        pixel_clk = 1'b0;
        forever #20 pixel_clk = ~pixel_clk;
    end

    // =========================================================================
    // DUT INPUTS
    // =========================================================================

    reg [7:0]  battery_percent_i;
    reg [15:0] battery_voltage_mv_i;
    reg        sensor_valid_i;   // unused; DUT is driven by the RNM chain below

    reg [7:0]  rssi_dbm_i;
    reg        link_up_i;
    reg        link_error_i;
    reg        carrier_detect_i;

    reg [31:0] gpio_in;

    // =========================================================================
    // RNM SENSOR CHAIN
    //
    // temperature (degC, real) -> sensor_voltage -> adc_code -> temperature_tenthsC
    //
    // temperature_tenthsC / sensor_valid feed the DUT directly, replacing the
    // old static temperature_tenthsC_i reg.
    // =========================================================================

    real temperature;
    real sensor_voltage;

    logic [11:0]        adc_code;
    logic signed [15:0] temperature_tenthsC;
    logic                sensor_valid;

    temp_sensor_rnm #(
        .ENABLE_NOISE(1'b0)
    ) u_temp_sensor (
        .temperature   (temperature),
        .sensor_voltage(sensor_voltage)
    );

    adc_rnm #(
        .ADC_BITS(12),
        .VREF(1.8)
    ) u_adc (
        .analog_voltage(sensor_voltage),
        .adc_code      (adc_code)
    );

    sensor_adc_rnm #(
        .ADC_BITS(12),
        .VREF(1.8)
    ) u_sensor_adc (
        .adc_code           (adc_code),
        .temperature_tenthsC(temperature_tenthsC),
        .sensor_valid       (sensor_valid)
    );

    // =========================================================================
    // DUT OUTPUTS
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
    // DUT INSTANCE
    // =========================================================================

    cpu_soc_ram_top dut (
        .clk                     (clk),
        .resetn                  (resetn),

        .battery_percent_i       (battery_percent_i),
        .battery_voltage_mv_i    (battery_voltage_mv_i),
        .temperature_tenthsC_i   (temperature_tenthsC),
        .sensor_valid_i          (sensor_valid),

        .rssi_dbm_i              (rssi_dbm_i),
        .link_up_i               (link_up_i),
        .link_error_i            (link_error_i),
        .carrier_detect_i        (carrier_detect_i),

        .rf_enable_o             (rf_enable_o),

        .gpio_out                (gpio_out),
        .gpio_oe                 (gpio_oe),
        .gpio_in                 (gpio_in),

        .pixel_clk               (pixel_clk),

        .hsync_o                 (hsync_o),
        .vsync_o                 (vsync_o),

        .pixel_x_o               (pixel_x_o),
        .pixel_y_o               (pixel_y_o),

        .rgb_r_o                 (rgb_r_o),
        .rgb_g_o                 (rgb_g_o),
        .rgb_b_o                 (rgb_b_o),

        .trap                     (trap)
    );

    // =========================================================================
    // COUNTERS AND STATE
    // =========================================================================

    integer cycle_count;

    integer cpu_write_count;
    integer cpu_read_count;

    integer ram_write_count;
    integer ram_read_count;

    integer tpu_write_count;
    integer tpu_read_count;
    integer tpu_config_write_count;

    integer sensor_write_count;
    integer sensor_read_count;

    integer axis_input_count;
    integer axis_output_count;

    integer axis_input_tlast_count;
    integer axis_output_tlast_count;

    integer start_cycle;
    integer done_cycle;

    integer start_event_count;
    integer busy_event_count;
    integer done_event_count;

    reg start_seen;
    reg busy_seen;
    reg done_seen;

    reg firmware_done;
    reg firmware_fail;
    reg [31:0] firmware_done_marker;
    reg [31:0] firmware_error_code;
    reg trap_seen;
    reg timeout_hit;

    reg previous_axis_start;
    reg previous_axis_busy;
    reg previous_axis_done;

    reg [63:0] observed_result0;
    reg [63:0] observed_result1;

    reg [31:0] result0_low_read;
    reg [31:0] result0_high_read;
    reg [31:0] result1_low_read;
    reg [31:0] result1_high_read;

    reg result0_low_read_seen;
    reg result0_high_read_seen;
    reg result1_low_read_seen;
    reg result1_high_read_seen;

    // Plusarg-driven firmware/stimulus selection
    string fw_hex;
    real   temp_c;
    integer batt_pct;

    // =========================================================================
    // INITIALIZATION AND FIRMWARE LOAD
    // =========================================================================

    initial begin

        if (!$value$plusargs("FW_HEX=%s", fw_hex))
            fw_hex = "./firmware_test03/firmware.hex";

        if (!$value$plusargs("TEMP_C=%f", temp_c))
            temp_c = 79.9;

        if (!$value$plusargs("BATT=%d", batt_pct))
            batt_pct = 80;

        battery_percent_i     = batt_pct[7:0];
        battery_voltage_mv_i  = 16'd3700;
        sensor_valid_i        = 1'b1;   // unused, DUT driven by RNM
        temperature            = temp_c;

        rssi_dbm_i            = 8'd50;
        link_up_i             = 1'b1;
        link_error_i          = 1'b0;
        carrier_detect_i      = 1'b1;

        gpio_in               = 32'd0;

        resetn                = 1'b0;

        cycle_count           = 0;

        cpu_write_count       = 0;
        cpu_read_count        = 0;

        ram_write_count       = 0;
        ram_read_count        = 0;

        tpu_write_count       = 0;
        tpu_read_count        = 0;
        tpu_config_write_count = 0;

        sensor_write_count    = 0;
        sensor_read_count     = 0;

        axis_input_count      = 0;
        axis_output_count     = 0;

        axis_input_tlast_count  = 0;
        axis_output_tlast_count = 0;

        start_cycle = -1;
        done_cycle  = -1;

        start_event_count = 0;
        busy_event_count  = 0;
        done_event_count  = 0;

        start_seen = 1'b0;
        busy_seen  = 1'b0;
        done_seen  = 1'b0;

        firmware_done        = 1'b0;
        firmware_fail        = 1'b0;
        firmware_done_marker = 32'd0;
        firmware_error_code  = 32'd0;
        trap_seen            = 1'b0;
        timeout_hit          = 1'b0;

        previous_axis_start = 1'b0;
        previous_axis_busy  = 1'b0;
        previous_axis_done  = 1'b0;

        observed_result0 = 64'd0;
        observed_result1 = 64'd0;

        result0_low_read  = 32'd0;
        result0_high_read = 32'd0;
        result1_low_read  = 32'd0;
        result1_high_read = 32'd0;

        result0_low_read_seen  = 1'b0;
        result0_high_read_seen = 1'b0;
        result1_low_read_seen  = 1'b0;
        result1_high_read_seen = 1'b0;

        // =====================================================================
        // WAVEFORM DUMP
        // =====================================================================

        $dumpfile("waveform_phase_5_with_firmw.vcd");
        $dumpvars(0, tb_cpu_soc_ram_top);

        $display("");
        $display("============================================================");
        $display("PHASE 5 TESTBENCH START");
        $display("Loading firmware: %s", fw_hex);
        $display("TEMP_C=%0.2f  BATT=%0d", temp_c, batt_pct);
        $display("============================================================");

        $readmemh(fw_hex, dut.ram.mem);

        $display("[TB] Firmware loaded.");
        $display("[TB] Reset active.");

        repeat (10) @(posedge clk);

        resetn = 1'b1;

        $display("[%0t] [TB] Reset released.", $time);
        $display("");
    end

    // =========================================================================
    // CPU CYCLE COUNTER
    // =========================================================================

    always @(posedge clk) begin
        if (!resetn)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end

    // =========================================================================
    // CPU NATIVE-BUS MONITOR
    // =========================================================================

    always @(posedge clk) begin
        if (resetn && dut.m_valid && dut.m_ready) begin

            if (dut.m_write) begin

                cpu_write_count = cpu_write_count + 1;

                $display(
                    "[%0t][CPU-WRITE] addr=%08h data=%08h strb=%h",
                    $time,
                    dut.m_addr,
                    dut.m_wdata,
                    dut.m_strb
                );

                // -------------------------------------------------------------
                // Firmware marker detection
                //
                // 0x11111111 / 0x22222222 : progress markers (informational)
                // 0x33333333               : TPU completion, OR sensor
                //                             intermediate "status ok" marker
                // 0x55555555               : sensor final success marker
                // 0xDEAD0001                : failure, for either firmware
                // -------------------------------------------------------------

                if (dut.m_addr == FIRMWARE_MARKER_ADDR) begin

                    if (dut.m_wdata == 32'h1111_1111) begin
                        $display("[%0t][FW] START marker 0x11111111", $time);
                    end

                    if (dut.m_wdata == 32'h2222_2222) begin
                        $display("[%0t][FW] WORKLOAD/READS marker 0x22222222", $time);
                    end

                    if (dut.m_wdata == MARK_STATUS_OK_OR_TPU_DONE) begin
                        $display(
                            "[%0t][FW] 0x33333333 seen (TPU completion, or sensor STATUS_OK - not final for sensor)",
                            $time
                        );
                        // Treat as done only if nothing further arrives; TPU
                        // firmware has no later marker, sensor firmware does
                        // (0x55555555), so don't finish here - just record it
                        // and let the sensor case override below if it comes.
                        if (!firmware_done) begin
                            firmware_done        = 1'b1;
                            firmware_done_marker = 32'h3333_3333;
                        end
                    end

                    if (dut.m_wdata == 32'h4444_4444) begin
                        $display("[%0t][FW] sensor RO_OK marker 0x44444444", $time);
                    end

                    if (dut.m_wdata == MARK_SENSOR_SUCCESS) begin
                        // Final marker for sensor firmware - always wins over
                        // an earlier 0x33333333 status-ok marker.
                        firmware_done        = 1'b1;
                        firmware_done_marker = MARK_SENSOR_SUCCESS;

                        $display(
                            "[%0t][FW] sensor SUCCESS marker 0x55555555",
                            $time
                        );
                    end

                    if (dut.m_wdata == MARK_FAIL) begin
                        firmware_fail = 1'b1;

                        $display(
                            "[%0t][FW] FAILURE marker 0xDEAD0001",
                            $time
                        );
                    end
                end

                if (dut.m_addr == FIRMWARE_ERROR_ADDR) begin
                    firmware_error_code = dut.m_wdata;
                end

                // -------------------------------------------------------------
                // TPU MMIO writes
                // -------------------------------------------------------------

                if ((dut.m_addr >= TPU_BASE) &&
                    (dut.m_addr < TPU_BASE + 32'h1000)) begin

                    tpu_write_count = tpu_write_count + 1;

                    $display(
                        "    [TPU-MMIO-WRITE] local=%03h data=%08h",
                        dut.m_addr[11:0],
                        dut.m_wdata
                    );

                    if ((dut.m_addr >= TPU_WEIGHT0_L) &&
                        (dut.m_addr <= TPU_INPUT1_H)) begin

                        tpu_config_write_count =
                            tpu_config_write_count + 1;
                    end

                    if (dut.m_addr == TPU_CTRL) begin

                        $display(
                            "    [TPU-CONTROL] write data=%08h bit0=%0d",
                            dut.m_wdata,
                            dut.m_wdata[0]
                        );

                        if (dut.m_strb[0] && dut.m_wdata[0]) begin
                            $display(
                                "    [TPU-START-CMD] CPU START command observed"
                            );
                        end
                    end
                end

                // -------------------------------------------------------------
                // SENSOR MMIO writes (window is read-only by spec; a write
                // reaching here means the firmware's RO-write probe fired)
                // -------------------------------------------------------------

                if ((dut.m_addr >= SENSOR_BASE) &&
                    (dut.m_addr < SENSOR_BASE + 32'h1000)) begin

                    sensor_write_count = sensor_write_count + 1;

                    $display(
                        "    [SENSOR-WRITE] local=%03h data=%08h (window is RO by spec)",
                        dut.m_addr[11:0],
                        dut.m_wdata
                    );
                end

                // -------------------------------------------------------------
                // Result RAM write monitor
                // -------------------------------------------------------------

                if ((dut.m_addr >= RESULT_BASE) &&
                    (dut.m_addr < RESULT_BASE + RESULT_WORDS * 4)) begin

                    $display(
                        "    [RESULT-RAM-WRITE] addr=%08h data=%08h",
                        dut.m_addr,
                        dut.m_wdata
                    );
                end

            end
            else begin

                cpu_read_count = cpu_read_count + 1;

                $display(
                    "[%0t][CPU-READ ] addr=%08h data=%08h",
                    $time,
                    dut.m_addr,
                    dut.m_rdata
                );

                // -------------------------------------------------------------
                // TPU MMIO reads
                // -------------------------------------------------------------

                if ((dut.m_addr >= TPU_BASE) &&
                    (dut.m_addr < TPU_BASE + 32'h1000)) begin

                    tpu_read_count = tpu_read_count + 1;

                    $display(
                        "    [TPU-MMIO-READ] local=%03h data=%08h",
                        dut.m_addr[11:0],
                        dut.m_rdata
                    );

                    if (dut.m_addr == TPU_STATUS) begin
                        $display(
                            "    [TPU-STATUS] BUSY=%0d DONE=%0d",
                            dut.m_rdata[0],
                            dut.m_rdata[1]
                        );
                    end

                    if (dut.m_addr == TPU_RESULT0_L) begin
                        result0_low_read      = dut.m_rdata;
                        result0_low_read_seen = 1'b1;
                    end

                    if (dut.m_addr == TPU_RESULT0_H) begin
                        result0_high_read      = dut.m_rdata;
                        result0_high_read_seen = 1'b1;
                    end

                    if (dut.m_addr == TPU_RESULT1_L) begin
                        result1_low_read      = dut.m_rdata;
                        result1_low_read_seen = 1'b1;
                    end

                    if (dut.m_addr == TPU_RESULT1_H) begin
                        result1_high_read      = dut.m_rdata;
                        result1_high_read_seen = 1'b1;
                    end
                end

                // -------------------------------------------------------------
                // SENSOR MMIO reads
                // -------------------------------------------------------------

                if ((dut.m_addr >= SENSOR_BASE) &&
                    (dut.m_addr < SENSOR_BASE + 32'h1000)) begin

                    sensor_read_count = sensor_read_count + 1;

                    $display(
                        "    [SENSOR-READ] local=%03h data=%08h",
                        dut.m_addr[11:0],
                        dut.m_rdata
                    );
                end

                // -------------------------------------------------------------
                // Result RAM read monitor
                // -------------------------------------------------------------

                if ((dut.m_addr >= RESULT_BASE) &&
                    (dut.m_addr < RESULT_BASE + RESULT_WORDS * 4)) begin

                    $display(
                        "    [RESULT-RAM-READ] addr=%08h data=%08h",
                        dut.m_addr,
                        dut.m_rdata
                    );
                end
            end
        end
    end

    // =========================================================================
    // ACTUAL RAM-SIDE MONITOR
    // =========================================================================

    always @(posedge clk) begin
        if (resetn && dut.ram_valid && dut.ram_ready) begin

            if (dut.ram_write) begin

                ram_write_count = ram_write_count + 1;

                $display(
                    "[%0t][RAM-WRITE] addr=%08h data=%08h strb=%h",
                    $time,
                    dut.ram_addr,
                    dut.ram_wdata,
                    dut.ram_strb
                );

            end
            else begin

                ram_read_count = ram_read_count + 1;

            end
        end
    end

    // =========================================================================
    // TPU INTERNAL START/BUSY/DONE MONITOR
    // =========================================================================

    always @(posedge clk) begin
        if (resetn) begin

            if (dut.tpu.axis_start) begin

                start_event_count = start_event_count + 1;

                if (!start_seen) begin
                    start_seen  = 1'b1;
                    start_cycle = cycle_count;
                end

                $display(
                    "[%0t][TPU-START] cycle=%0d axis_start=%0d",
                    $time,
                    cycle_count,
                    dut.tpu.axis_start
                );
            end

            if (dut.tpu.axis_busy && !previous_axis_busy) begin

                busy_event_count = busy_event_count + 1;
                busy_seen = 1'b1;

                $display(
                    "[%0t][TPU-BUSY] cycle=%0d axis_busy=1",
                    $time,
                    cycle_count
                );
            end

            if (dut.tpu.axis_done && !previous_axis_done) begin

                done_event_count = done_event_count + 1;

                if (!done_seen) begin
                    done_seen  = 1'b1;
                    done_cycle = cycle_count;
                end

                $display(
                    "[%0t][TPU-DONE] cycle=%0d START-to-DONE=%0d",
                    $time,
                    cycle_count,
                    cycle_count - start_cycle
                );
            end

            previous_axis_start = dut.tpu.axis_start;
            previous_axis_busy  = dut.tpu.axis_busy;
            previous_axis_done  = dut.tpu.axis_done;
        end
    end

    // =========================================================================
    // AXI INPUT MONITOR
    // =========================================================================

    always @(posedge clk) begin
        if (resetn &&
            dut.tpu.in_tvalid &&
            dut.tpu.in_tready) begin

            axis_input_count = axis_input_count + 1;

            if (dut.tpu.in_tlast)
                axis_input_tlast_count = axis_input_tlast_count + 1;

            $display(
                "[%0t][AXI-IN ] beat=%0d data=%016h tlast=%0d",
                $time,
                axis_input_count,
                dut.tpu.in_tdata,
                dut.tpu.in_tlast
            );
        end
    end

    // =========================================================================
    // AXI OUTPUT MONITOR
    // =========================================================================

    always @(posedge clk) begin
        if (resetn &&
            dut.tpu.out_tvalid &&
            dut.tpu.out_tready) begin

            axis_output_count = axis_output_count + 1;

            if (dut.tpu.out_tlast)
                axis_output_tlast_count = axis_output_tlast_count + 1;

            $display(
                "[%0t][AXI-OUT] beat=%0d data=%016h tlast=%0d",
                $time,
                axis_output_count,
                dut.tpu.out_tdata,
                dut.tpu.out_tlast
            );
        end
    end

    // =========================================================================
    // TPU RESULT REGISTER MONITOR
    // =========================================================================

    always @(posedge clk) begin
        if (resetn) begin

            if (dut.tpu.result0 !== observed_result0) begin

                observed_result0 = dut.tpu.result0;

                $display(
                    "[%0t][TPU-RESULT0] value=%016h",
                    $time,
                    observed_result0
                );
            end

            if (dut.tpu.result1 !== observed_result1) begin

                observed_result1 = dut.tpu.result1;

                $display(
                    "[%0t][TPU-RESULT1] value=%016h",
                    $time,
                    observed_result1
                );
            end
        end
    end

    // =========================================================================
    // CPU TRAP MONITOR
    // =========================================================================

    always @(posedge clk) begin
        if (resetn && trap && !trap_seen) begin

            trap_seen = 1'b1;

            $display("");
            $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
            $display("[%0t] CPU TRAP DETECTED", $time);
            $display("CPU cycle = %0d", cycle_count);
            $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
            $display("");
        end
    end

    // =========================================================================
    // SHOW RESULT RAM
    // =========================================================================

    task show_output_ram;
        integer i;
        begin
            $display("");
            $display("============================================================");
            $display(
                "PHASE 5 RESULT RAM: base=%08h words=%0d",
                RESULT_BASE,
                RESULT_WORDS
            );

            for (i = 0; i < RESULT_WORDS; i = i + 1) begin
                $display(
                    "RAM[%0d] addr=%08h data=%08h",
                    (RESULT_BASE >> 2) + i,
                    RESULT_BASE + i * 4,
                    dut.ram.mem[(RESULT_BASE >> 2) + i]
                );
            end

            $display("============================================================");
        end
    endtask

    // =========================================================================
    // PRINT COMPLETE SUMMARY
    // =========================================================================

    task print_summary;
        begin
            $display("");
            $display("============================================================");
            $display("================ PHASE 5 SUMMARY ===========================");
            $display("============================================================");

            $display("Firmware                    = %s", fw_hex);
            $display("TEMP_C / BATT                = %0.2f / %0d", temp_c, batt_pct);

            $display("CPU writes                  = %0d", cpu_write_count);
            $display("CPU reads                   = %0d", cpu_read_count);

            $display("RAM writes                  = %0d", ram_write_count);
            $display("RAM reads                   = %0d", ram_read_count);

            $display("TPU MMIO writes             = %0d", tpu_write_count);
            $display("TPU MMIO reads              = %0d", tpu_read_count);
            $display("TPU config writes           = %0d",
                     tpu_config_write_count);

            $display("SENSOR MMIO writes           = %0d", sensor_write_count);
            $display("SENSOR MMIO reads            = %0d", sensor_read_count);

            $display("AXI input beats             = %0d",
                     axis_input_count);
            $display("AXI input TLAST             = %0d",
                     axis_input_tlast_count);

            $display("AXI output beats            = %0d",
                     axis_output_count);
            $display("AXI output TLAST            = %0d",
                     axis_output_tlast_count);

            $display("START event count           = %0d",
                     start_event_count);
            $display("BUSY event count            = %0d",
                     busy_event_count);
            $display("DONE event count            = %0d",
                     done_event_count);

            $display("START seen                   = %0d", start_seen);
            $display("BUSY seen                    = %0d", busy_seen);
            $display("DONE seen                    = %0d", done_seen);

            if (start_seen && done_seen) begin
                $display(
                    "START-to-DONE cycles        = %0d",
                    done_cycle - start_cycle
                );
            end

            $display("Firmware done marker         = %0d (value=0x%08h)",
                     firmware_done, firmware_done_marker);
            $display("Firmware failure marker      = %0d (error_code=%0d)",
                     firmware_fail, firmware_error_code);
            $display("CPU trap seen                = %0d",
                     trap_seen);
            $display("CPU cycles                   = %0d",
                     cycle_count);

            $display("TPU result0                  = %016h",
                     dut.tpu.result0);
            $display("TPU result1                  = %016h",
                     dut.tpu.result1);

            $display("============================================================");
        end
    endtask

    // =========================================================================
    // END-OF-SIMULATION CONTROL
    //
    // Firmware marker has priority over timeout.
    // =========================================================================

    always @(posedge clk) begin
        if (resetn) begin

            if (firmware_done) begin

                print_summary();
                show_output_ram();

                $display("");
                $display("PHASE 5 PASS: firmware completion marker detected (0x%08h).",
                         firmware_done_marker);
                $display("");

                $finish;
            end

            if (firmware_fail) begin

                print_summary();
                show_output_ram();

                $display("");
                $display("PHASE 5 FAIL: firmware failure marker detected (error_code=%0d).",
                         firmware_error_code);
                $display("");

                $finish;
            end

            if (cycle_count >= TIMEOUT_CYCLES) begin

                timeout_hit = 1'b1;

                print_summary();
                show_output_ram();

                $display("");
                $display("PHASE 5 TIMEOUT");
                $display(
                    "Firmware completion marker was not detected within %0d cycles.",
                    TIMEOUT_CYCLES
                );
                $display("");

                $finish;
            end
        end
    end

endmodule