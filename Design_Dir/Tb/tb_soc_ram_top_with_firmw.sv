`timescale 1ns / 1ps

// =============================================================================
// tb_soc_ram_top_with_firmw.sv
//
// RISCV-VDP-SoC - Phase 5
// CPU firmware execution + TPU integration observation
//
// DUT:
//     cpu_soc_ram_top
//
// Firmware:
//     firmware.hex
//
// IMPORTANT:
//   This testbench does NOT invent expected TPU results.
//   It observes:
//     - CPU native-bus transactions
//     - RAM transactions
//     - TPU MMIO transactions
//     - TPU START/BUSY/DONE
//     - AXI4-Stream input handshakes
//     - AXI4-Stream output handshakes
//     - result register values
//     - CPU trap
//
// Verified DUT hierarchy from current repository:
//     dut.m_valid
//     dut.m_write
//     dut.m_addr
//     dut.m_wdata
//     dut.m_strb
//     dut.m_ready
//     dut.m_rdata
//
//     dut.ram_valid
//     dut.ram_write
//     dut.ram_addr
//     dut.ram_wdata
//     dut.ram_strb
//     dut.ram_ready
//     dut.ram_rdata
//     dut.ram.mem
//
//     dut.tpu
//       dut.tpu.axis_start
//       dut.tpu.axis_busy
//       dut.tpu.axis_done
//       dut.tpu.in_tvalid
//       dut.tpu.in_tready
//       dut.tpu.in_tdata
//       dut.tpu.in_tlast
//       dut.tpu.out_tvalid
//       dut.tpu.out_tready
//       dut.tpu.out_tdata
//       dut.tpu.out_tlast
//       dut.tpu.result0
//       dut.tpu.result1
//
// =============================================================================

module tb_cpu_soc_ram_top;

    // =========================================================================
    // PARAMETERS
    // =========================================================================

    localparam integer TIMEOUT_CYCLES = 1_000_000;

    // Firmware file used by $readmemh.
    localparam string FIRMWARE_FILE = "firmware.hex";

    // RAM output observation window.
    //
    // These are ONLY observation addresses. They are not used to declare an
    // expected result.
    //
    // 0x1220 was the output region used in the Phase-3/firmware flow.
    // Change these two values if the Phase-5 firmware uses a different RAM
    // output region.
    localparam [31:0] RESULT_BASE = 32'h0000_1230;
    localparam integer RESULT_WORDS = 4;

    // =========================================================================
    // TPU SYSTEM ADDRESS MAP
    //
    // These are the CPU-visible addresses from cpu_soc_ram_top /
    // soc_mem_interconnect.
    // =========================================================================

    localparam [31:0] TPU_BASE = 32'h0001_4000;

    localparam [31:0] TPU_CTRL    = TPU_BASE + 32'h0000;
    localparam [31:0] TPU_STATUS  = TPU_BASE + 32'h0004;

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

    localparam [31:0] TPU_INPUT0_L  = TPU_BASE + 32'h0038;
    localparam [31:0] TPU_INPUT0_H  = TPU_BASE + 32'h003C;

    localparam [31:0] TPU_INPUT1_L  = TPU_BASE + 32'h0040;
    localparam [31:0] TPU_INPUT1_H  = TPU_BASE + 32'h0044;

    localparam [31:0] TPU_RESULT0_L = TPU_BASE + 32'h0050;
    localparam [31:0] TPU_RESULT0_H = TPU_BASE + 32'h0054;

    localparam [31:0] TPU_RESULT1_L = TPU_BASE + 32'h0058;
    localparam [31:0] TPU_RESULT1_H = TPU_BASE + 32'h005C;

    // =========================================================================
    // CLOCK / RESET
    // =========================================================================

    reg clk;
    reg resetn;
    reg pixel_clk;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
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
    reg [15:0] temperature_tenthsC_i;
    reg        sensor_valid_i;

    reg [7:0]  rssi_dbm_i;
    reg        link_up_i;
    reg        link_error_i;
    reg        carrier_detect_i;

    reg [31:0] gpio_in;

    // =========================================================================
    // DUT OUTPUTS
    // =========================================================================

    wire       rf_enable_o;

    wire [31:0] gpio_out;
    wire [31:0] gpio_oe;

    wire       hsync_o;
    wire       vsync_o;

    wire [11:0] pixel_x_o;
    wire [11:0] pixel_y_o;

    wire [3:0] rgb_r_o;
    wire [3:0] rgb_g_o;
    wire [3:0] rgb_b_o;

    wire trap;

    // =========================================================================
    // DUT
    // =========================================================================

    cpu_soc_ram_top dut (
        .clk                     (clk),
        .resetn                  (resetn),

        .battery_percent_i       (battery_percent_i),
        .battery_voltage_mv_i    (battery_voltage_mv_i),
        .temperature_tenthsC_i   (temperature_tenthsC_i),
        .sensor_valid_i          (sensor_valid_i),

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
    // TESTBENCH STATE / COUNTERS
    // =========================================================================

    integer cycle_count;

    integer cpu_write_count;
    integer cpu_read_count;

    integer ram_write_count;
    integer ram_read_count;

    integer tpu_write_count;
    integer tpu_read_count;

    integer tpu_config_write_count;

    integer input_axis_handshake_count;
    integer output_axis_handshake_count;

    integer input_tlast_count;
    integer output_tlast_count;

    integer timeout_hit;

    reg start_seen;
    reg busy_seen;
    reg done_seen;

    reg trap_seen;

    integer start_cycle;
    integer done_cycle;

    reg previous_busy;
    reg previous_done;

    // =========================================================================
    // RESULT OBSERVATION
    // =========================================================================

    reg [63:0] observed_result0;
    reg [63:0] observed_result1;

    reg result0_seen;
    reg result1_seen;

    // CPU MMIO result-read halves.
    reg [31:0] result0_low_read;
    reg [31:0] result0_high_read;
    reg [31:0] result1_low_read;
    reg [31:0] result1_high_read;

    reg result0_low_read_seen;
    reg result0_high_read_seen;
    reg result1_low_read_seen;
    reg result1_high_read_seen;

    // =========================================================================
    // FIRMWARE LOADING
    //
    // soc_ram.mem is a real memory array in the current RTL.
    // =========================================================================

    initial begin
        $display("");
        $display("============================================================");
        $display("PHASE 5 - FIRMWARE / TPU TESTBENCH");
        $display("============================================================");
        $display("Loading firmware: %s", FIRMWARE_FILE);

        $readmemh(FIRMWARE_FILE, dut.ram.mem);

        $display("Firmware load command completed.");
        $display("============================================================");
        $display("");
    end

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    initial begin

        battery_percent_i     = 8'd80;
        battery_voltage_mv_i  = 16'd3700;
        temperature_tenthsC_i = 16'd250;
        sensor_valid_i        = 1'b1;

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

        input_axis_handshake_count  = 0;
        output_axis_handshake_count = 0;

        input_tlast_count  = 0;
        output_tlast_count = 0;

        timeout_hit = 0;

        start_seen = 1'b0;
        busy_seen  = 1'b0;
        done_seen  = 1'b0;
        trap_seen  = 1'b0;

        start_cycle = -1;
        done_cycle  = -1;

        previous_busy = 1'b0;
        previous_done = 1'b0;

        observed_result0 = 64'd0;
        observed_result1 = 64'd0;

        result0_seen = 1'b0;
        result1_seen = 1'b0;

        result0_low_read  = 32'd0;
        result0_high_read = 32'd0;
        result1_low_read  = 32'd0;
        result1_high_read = 32'd0;

        result0_low_read_seen  = 1'b0;
        result0_high_read_seen = 1'b0;
        result1_low_read_seen  = 1'b0;
        result1_high_read_seen = 1'b0;

        repeat (10) @(posedge clk);

        resetn = 1'b1;

        $display("[%0t] RESET RELEASED", $time);
        $display("");

    end

    // =========================================================================
    // MAIN CYCLE COUNTER / TRAP / TIMEOUT
    // =========================================================================

    always @(posedge clk) begin

        if (!resetn) begin
            cycle_count <= 0;
        end
        else begin

            cycle_count <= cycle_count + 1;

            if (trap && !trap_seen) begin
                trap_seen <= 1'b1;

                $display("");
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                $display("[%0t] CPU TRAP OBSERVED", $time);
                $display("cycle = %0d", cycle_count);
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                $display("");
            end

            if (cycle_count >= TIMEOUT_CYCLES) begin

                timeout_hit <= 1;

                $display("");
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                $display("TIMEOUT");
                $display("TIMEOUT_CYCLES = %0d", TIMEOUT_CYCLES);
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                $display("");

                print_summary();
                show_output_ram();

                $finish;
            end
        end
    end

    // =========================================================================
    // CPU NATIVE BUS MONITOR
    //
    // A transaction is considered completed when:
    //
    //     m_valid && m_ready
    //
    // This matches the actual CPU master/interconnect interface.
    // =========================================================================

    always @(posedge clk) begin

        if (resetn) begin

            if (dut.m_valid && dut.m_ready) begin

                if (dut.m_write) begin

                    cpu_write_count = cpu_write_count + 1;

                    $display(
                        "[%0t][CPU-WRITE] addr=0x%08h data=0x%08h strb=0x%1h",
                        $time,
                        dut.m_addr,
                        dut.m_wdata,
                        dut.m_strb
                    );

                    // ---------------------------------------------------------
                    // TPU MMIO WRITE
                    // ---------------------------------------------------------

                    if ((dut.m_addr >= TPU_BASE) &&
                        (dut.m_addr < (TPU_BASE + 32'h1000))) begin

                        tpu_write_count = tpu_write_count + 1;

                        $display(
                            "    [TPU-MMIO-WRITE] addr=0x%08h local=0x%03h data=0x%08h",
                            dut.m_addr,
                            dut.m_addr[11:0],
                            dut.m_wdata
                        );
                                // can be made to 14 to avoid gaps
                        if ((dut.m_addr >= TPU_WEIGHT0_L) &&
                            (dut.m_addr <= TPU_INPUT1_H)) begin

                            tpu_config_write_count =
                                tpu_config_write_count + 1;

                        end

                        if (dut.m_addr == TPU_CTRL) begin

                            if (dut.m_strb[0] && dut.m_wdata[0]) begin
                                $display(
                                    "    [TPU-CMD] START write observed; axis_start acceptance depends on TPU busy state."
                                );
                            end

                        end

                    end

                    // ---------------------------------------------------------
                    // RAM OUTPUT REGION OBSERVATION
                    // ---------------------------------------------------------

                    if ((dut.m_addr >= RESULT_BASE) &&
                        (dut.m_addr < (RESULT_BASE +
                                       OUTPUT_WORDS * 4))) begin

                        $display(
                            "    [RAM-OUTPUT-WRITE] addr=0x%08h data=0x%08h",
                            dut.m_addr,
                            dut.m_wdata
                        );

                    end

                end
                else begin

                    cpu_read_count = cpu_read_count + 1;

                    $display(
                        "[%0t][CPU-READ ] addr=0x%08h data=0x%08h",
                        $time,
                        dut.m_addr,
                        dut.m_rdata
                    );

                    // ---------------------------------------------------------
                    // TPU MMIO READ
                    // ---------------------------------------------------------

                    if ((dut.m_addr >= TPU_BASE) &&
                        (dut.m_addr < (TPU_BASE + 32'h1000))) begin

                        tpu_read_count = tpu_read_count + 1;

                        $display(
                            "    [TPU-MMIO-READ] addr=0x%08h local=0x%03h data=0x%08h",
                            dut.m_addr,
                            dut.m_addr[11:0],
                            dut.m_rdata
                        );

                        // STATUS:
                        // bit 0 = BUSY
                        // bit 1 = DONE
                        if (dut.m_addr == TPU_STATUS) begin

                            $display(
                                "    [TPU-STATUS] BUSY=%0d DONE=%0d",
                                dut.m_rdata[0],
                                dut.m_rdata[1]
                            );

                        end

                        // RESULT0
                        if (dut.m_addr == TPU_RESULT0_L) begin
                            result0_low_read = dut.m_rdata;
                            result0_low_read_seen = 1'b1;
                        end

                        if (dut.m_addr == TPU_RESULT0_H) begin
                            result0_high_read = dut.m_rdata;
                            result0_high_read_seen = 1'b1;
                        end

                        // RESULT1
                        if (dut.m_addr == TPU_RESULT1_L) begin
                            result1_low_read = dut.m_rdata;
                            result1_low_read_seen = 1'b1;
                        end

                        if (dut.m_addr == TPU_RESULT1_H) begin
                            result1_high_read = dut.m_rdata;
                            result1_high_read_seen = 1'b1;
                        end

                    end

                    // ---------------------------------------------------------
                    // RAM OUTPUT REGION OBSERVATION
                    // ---------------------------------------------------------

                    if ((dut.m_addr >= RESULT_BASE) &&
                        (dut.m_addr < (RESULT_BASE +
                                       OUTPUT_WORDS * 4))) begin

                        $display(
                            "    [RAM-OUTPUT-READ] addr=0x%08h data=0x%08h",
                            dut.m_addr,
                            dut.m_rdata
                        );

                    end

                end
            end
        end
    end

    // =========================================================================
    // DIRECT RAM INTERFACE MONITOR
    //
    // This is useful because it observes the actual RAM-side transaction after
    // address decoding.
    // =========================================================================

    always @(posedge clk) begin

        if (resetn) begin

            if (dut.ram_valid && dut.ram_ready) begin

                if (dut.ram_write) begin

                    ram_write_count = ram_write_count + 1;

                    if ((dut.ram_addr >= RESULT_BASE) &&
                        (dut.ram_addr < (RESULT_BASE +
                                         OUTPUT_WORDS * 4))) begin

                        $display(
                            "[%0t][RAM-WRITE] addr=0x%08h data=0x%08h strb=0x%1h",
                            $time,
                            dut.ram_addr,
                            dut.ram_wdata,
                            dut.ram_strb
                        );

                    end

                end
                else begin

                    ram_read_count = ram_read_count + 1;

                    if ((dut.ram_addr >= RESULT_BASE) &&
                        (dut.ram_addr < (RESULT_BASE +
                                         OUTPUT_WORDS * 4))) begin

                        $display(
                            "[%0t][RAM-READ ] addr=0x%08h data=0x%08h",
                            $time,
                            dut.ram_addr,
                            dut.ram_rdata
                        );

                    end

                end
            end
        end
    end

    // =========================================================================
    // TPU STATUS MONITOR
    //
    // Directly observes the verified TPU internal signals.
    // =========================================================================

    always @(posedge clk) begin

        if (resetn) begin

            // ---------------------------------------------------------
            // START
            // ---------------------------------------------------------

            if (dut.tpu.axis_start) begin

                if (!start_seen) begin

                    start_seen  = 1'b1;
                    start_cycle = cycle_count;

                    $display("");
                    $display(
                        "[%0t][TPU] AXIS START asserted at cycle %0d",
                        $time,
                        cycle_count
                    );
                    $display("");

                end

            end

            // ---------------------------------------------------------
            // BUSY rising edge
            // ---------------------------------------------------------

            if (dut.tpu.axis_busy && !previous_busy) begin

                busy_seen = 1'b1;

                $display(
                    "[%0t][TPU] BUSY asserted at cycle %0d",
                    $time,
                    cycle_count
                );

            end

            // ---------------------------------------------------------
            // DONE rising edge
            // ---------------------------------------------------------

            if (dut.tpu.axis_done && !previous_done) begin

                done_seen  = 1'b1;
                done_cycle = cycle_count;

                $display("");
                $display(
                    "[%0t][TPU] DONE asserted at cycle %0d",
                    $time,
                    cycle_count
                );

                if (start_seen) begin
                    $display(
                        "[TPU] Observed START-to-DONE cycles = %0d",
                        done_cycle - start_cycle
                    );
                end

                $display("");

            end

            previous_busy = dut.tpu.axis_busy;
            previous_done = dut.tpu.axis_done;

        end

    end

    // =========================================================================
    // AXI4-STREAM INPUT MONITOR
    //
    // A beat is transferred only when:
    //
    //     in_tvalid && in_tready
    //
    // TLAST is reported only on an actual transferred beat.
    // =========================================================================

    always @(posedge clk) begin

        if (resetn) begin

            if (dut.tpu.in_tvalid && dut.tpu.in_tready) begin

                input_axis_handshake_count =
                    input_axis_handshake_count + 1;

                $display(
                    "[%0t][AXIS-IN ] beat=%0d data=0x%016h tlast=%0d",
                    $time,
                    input_axis_handshake_count,
                    dut.tpu.in_tdata,
                    dut.tpu.in_tlast
                );

                if (dut.tpu.in_tlast) begin

                    input_tlast_count = input_tlast_count + 1;

                    $display(
                        "    [AXIS-IN ] TLAST transferred."
                    );

                end

            end

        end

    end

    // =========================================================================
    // AXI4-STREAM OUTPUT MONITOR
    //
    // A beat is transferred only when:
    //
    //     out_tvalid && out_tready
    // =========================================================================

    always @(posedge clk) begin

        if (resetn) begin

            if (dut.tpu.out_tvalid && dut.tpu.out_tready) begin

                output_axis_handshake_count =
                    output_axis_handshake_count + 1;

                $display(
                    "[%0t][AXIS-OUT] beat=%0d data=0x%016h tlast=%0d",
                    $time,
                    output_axis_handshake_count,
                    dut.tpu.out_tdata,
                    dut.tpu.out_tlast
                );

                if (dut.tpu.out_tlast) begin

                    output_tlast_count = output_tlast_count + 1;

                    $display(
                        "    [AXIS-OUT] TLAST transferred."
                    );

                end

            end

        end

    end

    // =========================================================================
    // DIRECT TPU RESULT OBSERVATION
    //
    // These are the actual result signals exported by tpu_axis_top.
    // No expected value is assumed.
    // =========================================================================

    always @(posedge clk) begin

        if (resetn) begin

            if (dut.tpu.result0 !== observed_result0) begin

                observed_result0 = dut.tpu.result0;
                result0_seen     = 1'b1;

                $display(
                    "[%0t][TPU-RESULT0] observed = 0x%016h",
                    $time,
                    dut.tpu.result0
                );

            end

            if (dut.tpu.result1 !== observed_result1) begin

                observed_result1 = dut.tpu.result1;
                result1_seen     = 1'b1;

                $display(
                    "[%0t][TPU-RESULT1] observed = 0x%016h",
                    $time,
                    dut.tpu.result1
                );

            end

        end

    end

    // =========================================================================
    // OUTPUT RAM DUMP
    //
    // This reads the actual simulation memory array.
    // It does NOT compare against an invented expected value.
    // =========================================================================

    task show_output_ram;

        integer i;
        integer word_index;

        begin

            $display("");
            $display("============================================================");
            $display("RAM OUTPUT OBSERVATION");
            $display("Base address = 0x%08h", RESULT_BASE);
            $display("Words        = %0d", OUTPUT_WORDS);
            $display("============================================================");

            for (i = 0; i < OUTPUT_WORDS; i = i + 1) begin

                word_index = (RESULT_BASE >> 2) + i;

                $display(
                    "RAM[%0d] addr=0x%08h data=0x%08h",
                    word_index,
                    RESULT_BASE + (i * 4),
                    dut.ram.mem[word_index]
                );

            end

            $display("============================================================");
            $display("");

        end

    endtask

    // =========================================================================
    // TPU REGISTER SUMMARY
    //
    // Reads the internal register values directly for debugging.
    // These are observations, not expected-value checks.
    // =========================================================================

    task show_tpu_registers;

        begin

            $display("");
            $display("============================================================");
            $display("TPU INTERNAL REGISTER OBSERVATION");
            $display("============================================================");

            $display(
                "weight0 = 0x%016h",
                dut.tpu.u_nn_axi_wrapper.weight0
            );

            $display(
                "weight1 = 0x%016h",
                dut.tpu.u_nn_axi_wrapper.weight1
            );

            $display(
                "weight2 = 0x%016h",
                dut.tpu.u_nn_axi_wrapper.weight2
            );

            $display(
                "weight3 = 0x%016h",
                dut.tpu.u_nn_axi_wrapper.weight3
            );

            $display(
                "weight4 = 0x%016h",
                dut.tpu.u_nn_axi_wrapper.weight4
            );

            $display(
                "input0  = 0x%016h",
                dut.tpu.u_nn_axi_wrapper.input0
            );

            $display(
                "input1  = 0x%016h",
                dut.tpu.u_nn_axi_wrapper.input1
            );

            $display(
                "axis_busy = %0d",
                dut.tpu.axis_busy
            );

            $display(
                "axis_done = %0d",
                dut.tpu.axis_done
            );

            $display(
                "result0 = 0x%016h",
                dut.tpu.result0
            );

            $display(
                "result1 = 0x%016h",
                dut.tpu.result1
            );

            $display("============================================================");
            $display("");

        end

    endtask

    // =========================================================================
    // FINAL SUMMARY
    // =========================================================================

    task print_summary;

        begin

            $display("");
            $display("################################################################");
            $display("                    PHASE 5 SUMMARY");
            $display("################################################################");

            $display("");
            $display("CPU");
            $display("  CPU writes             : %0d", cpu_write_count);
            $display("  CPU reads              : %0d", cpu_read_count);
            $display("  Trap observed          : %0d", trap_seen);

            $display("");
            $display("RAM");
            $display("  RAM writes             : %0d", ram_write_count);
            $display("  RAM reads              : %0d", ram_read_count);

            $display("");
            $display("TPU MMIO");
            $display("  TPU writes             : %0d", tpu_write_count);
            $display("  TPU reads              : %0d", tpu_read_count);
            $display("  TPU configuration writes: %0d",
                     tpu_config_write_count);

            $display("");
            $display("TPU CONTROL / STATUS");
            $display("  START observed         : %0d", start_seen);
            $display("  BUSY observed          : %0d", busy_seen);
            $display("  DONE observed          : %0d", done_seen);

            if (start_seen)
                $display("  START cycle            : %0d", start_cycle);

            if (done_seen)
                $display("  DONE cycle             : %0d", done_cycle);

            if (start_seen && done_seen)
                $display(
                    "  START -> DONE cycles   : %0d",
                    done_cycle - start_cycle
                );

            $display("");
            $display("AXI4-STREAM INPUT");
            $display("  Transferred beats      : %0d",
                     input_axis_handshake_count);
            $display("  Transferred TLAST      : %0d",
                     input_tlast_count);

            $display("");
            $display("AXI4-STREAM OUTPUT");
            $display("  Transferred beats      : %0d",
                     output_axis_handshake_count);
            $display("  Transferred TLAST      : %0d",
                     output_tlast_count);

            $display("");
            $display("TPU RESULTS");
            $display("  result0 observed       : %0d", result0_seen);
            $display("  result1 observed       : %0d", result1_seen);
            $display("  result0                : 0x%016h",
                     dut.tpu.result0);
            $display("  result1                : 0x%016h",
                     dut.tpu.result1);

            $display("");
            $display("CPU READBACK OF RESULTS");

            if (result0_low_read_seen &&
                result0_high_read_seen) begin

                $display(
                    "  result0 readback       : 0x%016h",
                    {result0_high_read, result0_low_read}
                );

            end
            else begin

                $display(
                    "  result0 readback       : not completely observed"
                );

            end

            if (result1_low_read_seen &&
                result1_high_read_seen) begin

                $display(
                    "  result1 readback       : 0x%016h",
                    {result1_high_read, result1_low_read}
                );

            end
            else begin

                $display(
                    "  result1 readback       : not completely observed"
                );

            end

            $display("");
            $display("TIMEOUT");
            $display("  Timeout hit            : %0d", timeout_hit);

            $display("");
            $display("################################################################");
            $display("");

        end

    endtask

    // =========================================================================
    // END CONDITION
    //
    // We do not assume that DONE means the firmware has finished its entire
    // software flow. Therefore we do NOT automatically finish on TPU DONE.
    //
    // The simulation ends on:
    //   1. CPU trap, or
    //   2. timeout.
    //
    // After trap, give the firmware a few cycles to settle, dump observations,
    // then finish.
    // =========================================================================

    always @(posedge clk) begin

        if (resetn && trap && !trap_seen) begin

            fork
                begin
                    repeat (10) @(posedge clk);

                    show_tpu_registers();
                    show_output_ram();
                    print_summary();

                    $display("PHASE 5 SIMULATION FINISHED AFTER CPU TRAP.");
                    $finish;
                end
            join_none

        end

    end

    // =========================================================================
    // VCD
    // =========================================================================

    initial begin

        $dumpfile("phase5_soc_tpu.vcd");

        $dumpvars(0, tb_cpu_soc_ram_top);

    end

endmodule