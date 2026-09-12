`timescale 1ns / 1ps

// =============================================================================
// RISCV-VDP-SoC - Phase 5
// CPU firmware execution + TPU integration observation
//
// Firmware result RAM region: 0x1230 - 0x123C
// Firmware completion marker:  0x12A8 = 0x33333333
// Firmware failure marker:     0x12A8 = 0xDEAD0001
// TPU base:                    0x14000
// =============================================================================
module tb_cpu_soc_ram_top;

    localparam integer TIMEOUT_CYCLES = 1_000_000;
    localparam [31:0] FIRMWARE_MARKER_ADDR = 32'h0000_12A8;
    localparam [31:0] RESULT_BASE = 32'h0000_1230;
    localparam integer RESULT_WORDS = 4;

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

    reg clk, resetn, pixel_clk;
    reg [7:0] battery_percent_i;
    reg [15:0] battery_voltage_mv_i, temperature_tenthsC_i;
    reg sensor_valid_i;
    reg [7:0] rssi_dbm_i;
    reg link_up_i, link_error_i, carrier_detect_i;
    reg [31:0] gpio_in;

    wire rf_enable_o;
    wire [31:0] gpio_out, gpio_oe;
    wire hsync_o, vsync_o;
    wire [11:0] pixel_x_o, pixel_y_o;
    wire [3:0] rgb_r_o, rgb_g_o, rgb_b_o;
    wire trap;

    cpu_soc_ram_top dut (
        .clk(clk), .resetn(resetn),
        .battery_percent_i(battery_percent_i),
        .battery_voltage_mv_i(battery_voltage_mv_i),
        .temperature_tenthsC_i(temperature_tenthsC_i),
        .sensor_valid_i(sensor_valid_i),
        .rssi_dbm_i(rssi_dbm_i), .link_up_i(link_up_i),
        .link_error_i(link_error_i), .carrier_detect_i(carrier_detect_i),
        .rf_enable_o(rf_enable_o), .gpio_out(gpio_out), .gpio_oe(gpio_oe),
        .gpio_in(gpio_in), .pixel_clk(pixel_clk),
        .hsync_o(hsync_o), .vsync_o(vsync_o),
        .pixel_x_o(pixel_x_o), .pixel_y_o(pixel_y_o),
        .rgb_r_o(rgb_r_o), .rgb_g_o(rgb_g_o), .rgb_b_o(rgb_b_o),
        .trap(trap)
    );

    integer cycle_count;
    integer cpu_write_count, cpu_read_count;
    integer ram_write_count, ram_read_count;
    integer tpu_write_count, tpu_read_count, tpu_config_write_count;
    integer axis_in_count, axis_out_count, axis_in_tlast_count, axis_out_tlast_count;
    integer start_cycle, done_cycle;
    reg start_seen, done_seen, previous_busy, previous_done;
    reg firmware_done, firmware_fail, timeout_hit;
    reg [63:0] observed_result0, observed_result1;

    initial begin clk = 1'b0; forever #5 clk = ~clk; end
    initial begin pixel_clk = 1'b0; forever #20 pixel_clk = ~pixel_clk; end

    initial begin
        battery_percent_i = 8'd80;
        battery_voltage_mv_i = 16'd3700;
        temperature_tenthsC_i = 16'd250;
        sensor_valid_i = 1'b1;
        rssi_dbm_i = 8'd50;
        link_up_i = 1'b1;
        link_error_i = 1'b0;
        carrier_detect_i = 1'b1;
        gpio_in = 32'd0;
        resetn = 1'b0;
        cycle_count = 0;
        cpu_write_count = 0; cpu_read_count = 0;
        ram_write_count = 0; ram_read_count = 0;
        tpu_write_count = 0; tpu_read_count = 0; tpu_config_write_count = 0;
        axis_in_count = 0; axis_out_count = 0;
        axis_in_tlast_count = 0; axis_out_tlast_count = 0;
        start_cycle = -1; done_cycle = -1;
        start_seen = 0; done_seen = 0; previous_busy = 0; previous_done = 0;
        firmware_done = 0; firmware_fail = 0; timeout_hit = 0;
        observed_result0 = 0; observed_result1 = 0;
        $readmemh("firmware.hex", dut.ram.mem);
        repeat (10) @(posedge clk);
        resetn = 1'b1;
        $display("[TB] Phase 5 reset released; firmware loaded.");
    end

    // CPU transaction monitor, including firmware terminal markers.
    always @(posedge clk) begin
        if (resetn) begin
            if (dut.m_valid && dut.m_ready) begin
                if (dut.m_write) begin
                    cpu_write_count = cpu_write_count + 1;
                    $display("[CPU-WRITE] addr=%08h data=%08h strb=%h", dut.m_addr, dut.m_wdata, dut.m_strb);
                    if (dut.m_addr == FIRMWARE_MARKER_ADDR && dut.m_strb[0]) begin
                        if (dut.m_wdata == 32'h2222_2222)
                            $display("[FW] workload marker 0x22222222");
                        else if (dut.m_wdata == 32'h3333_3333)
                            firmware_done = 1'b1;
                        else if (dut.m_wdata == 32'hDEAD_0001)
                            firmware_fail = 1'b1;
                    end
                    if ((dut.m_addr >= TPU_BASE) && (dut.m_addr < TPU_BASE + 32'h1000)) begin
                        tpu_write_count = tpu_write_count + 1;
                        if ((dut.m_addr >= TPU_WEIGHT0_L) && (dut.m_addr <= TPU_INPUT1_H))
                            tpu_config_write_count = tpu_config_write_count + 1;
                    end
                end else begin
                    cpu_read_count = cpu_read_count + 1;
                    $display("[CPU-READ ] addr=%08h data=%08h", dut.m_addr, dut.m_rdata);
                    if ((dut.m_addr >= TPU_BASE) && (dut.m_addr < TPU_BASE + 32'h1000)) begin
                        tpu_read_count = tpu_read_count + 1;
                        if (dut.m_addr == TPU_STATUS)
                            $display("[TPU-STATUS] BUSY=%0d DONE=%0d", dut.m_rdata[0], dut.m_rdata[1]);
                    end
                end
            end
        end
    end

    // Actual RAM-side transactions.
    always @(posedge clk) begin
        if (resetn && dut.ram_valid && dut.ram_ready) begin
            if (dut.ram_write) begin
                ram_write_count = ram_write_count + 1;
                if ((dut.ram_addr >= RESULT_BASE) && (dut.ram_addr < RESULT_BASE + RESULT_WORDS*4))
                    $display("[RAM-WRITE] addr=%08h data=%08h", dut.ram_addr, dut.ram_wdata);
            end else begin
                ram_read_count = ram_read_count + 1;
            end
        end
    end

    // TPU status and START-to-DONE latency.
    always @(posedge clk) begin
        if (resetn) begin
            if (dut.tpu.axis_start && !start_seen) begin
                start_seen = 1'b1;
                start_cycle = cycle_count;
                $display("[TPU] START cycle=%0d", cycle_count);
            end
            if (dut.tpu.axis_busy && !previous_busy)
                $display("[TPU] BUSY cycle=%0d", cycle_count);
            if (dut.tpu.axis_done && !previous_done) begin
                done_seen = 1'b1;
                done_cycle = cycle_count;
                $display("[TPU] DONE cycle=%0d START-to-DONE=%0d", cycle_count, cycle_count-start_cycle);
            end
            previous_busy = dut.tpu.axis_busy;
            previous_done = dut.tpu.axis_done;
        end
    end

    always @(posedge clk) begin
        if (resetn && dut.tpu.in_tvalid && dut.tpu.in_tready) begin
            axis_in_count = axis_in_count + 1;
            $display("[AXIS-IN ] beat=%0d data=%016h tlast=%0d", axis_in_count, dut.tpu.in_tdata, dut.tpu.in_tlast);
            if (dut.tpu.in_tlast) axis_in_tlast_count = axis_in_tlast_count + 1;
        end
    end

    always @(posedge clk) begin
        if (resetn && dut.tpu.out_tvalid && dut.tpu.out_tready) begin
            axis_out_count = axis_out_count + 1;
            $display("[AXIS-OUT] beat=%0d data=%016h tlast=%0d", axis_out_count, dut.tpu.out_tdata, dut.tpu.out_tlast);
            if (dut.tpu.out_tlast) axis_out_tlast_count = axis_out_tlast_count + 1;
        end
    end

    always @(posedge clk) begin
        if (resetn) begin
            if (dut.tpu.result0 !== observed_result0) begin observed_result0 = dut.tpu.result0; $display("[TPU-RESULT0] %016h", observed_result0); end
            if (dut.tpu.result1 !== observed_result1) begin observed_result1 = dut.tpu.result1; $display("[TPU-RESULT1] %016h", observed_result1); end
        end
    end

    always @(posedge clk) begin
        if (!resetn) cycle_count <= 0;
        else cycle_count <= cycle_count + 1;
    end

    task show_output_ram;
        integer i;
        begin
            $display("============================================================");
            $display("PHASE 5 RESULT RAM: base=0x%08h words=%0d", RESULT_BASE, RESULT_WORDS);
            for (i=0; i<RESULT_WORDS; i=i+1)
                $display("RAM[%0d] addr=%08h data=%08h", (RESULT_BASE>>2)+i, RESULT_BASE+i*4, dut.ram.mem[(RESULT_BASE>>2)+i]);
            $display("============================================================");
        end
    endtask

    task print_summary;
        begin
            $display("");
            $display("================ PHASE 5 SUMMARY ================");
            $display("CPU writes=%0d reads=%0d", cpu_write_count, cpu_read_count);
            $display("RAM writes=%0d reads=%0d", ram_write_count, ram_read_count);
            $display("TPU writes=%0d reads=%0d config_writes=%0d", tpu_write_count, tpu_read_count, tpu_config_write_count);
            $display("AXIS input beats=%0d TLAST=%0d", axis_in_count, axis_in_tlast_count);
            $display("AXIS output beats=%0d TLAST=%0d", axis_out_count, axis_out_tlast_count);
            $display("START seen=%0d DONE seen=%0d", start_seen, done_seen);
            if (start_seen && done_seen) $display("START-to-DONE cycles=%0d", done_cycle-start_cycle);
            $display("CPU cycles=%0d", cycle_count);
            $display("=================================================");
        end
    endtask

    always @(posedge clk) begin
        if (resetn && (firmware_done || firmware_fail)) begin
            print_summary();
            show_output_ram();
            if (firmware_done) $display("PHASE 5 PASS: firmware marker 0x33333333");
            else $display("PHASE 5 FAIL: firmware marker 0xDEAD0001");
            $finish;
        end
        if (resetn && cycle_count >= TIMEOUT_CYCLES) begin
            timeout_hit = 1'b1;
            print_summary();
            show_output_ram();
            $display("PHASE 5 TIMEOUT");
            $finish;
        end
    end

endmodule
