`timescale 1ns / 1ps

module tb_cpu_soc_ram_top;

    // =========================================================================
    // PARAMETERS
    // =========================================================================

    localparam integer DATA_WIDTH = 32;
    localparam integer GPIO_WIDTH = 32;
    localparam integer RAM_DEPTH  = 16384;

    localparam integer CLK_PERIOD       = 10;
    localparam integer PIXEL_CLK_PERIOD = 20;

    localparam integer TIMEOUT_CYCLES = 1_000_000;

    // =========================================================================
    // CLOCK AND RESET
    // =========================================================================

    reg clk;
    reg pixel_clk;
    reg resetn;

    // =========================================================================
    // SENSOR INPUTS
    // =========================================================================

    reg [7:0]  battery_percent_i;
    reg [15:0] battery_voltage_mv_i;
    reg [15:0] temperature_tenthsC_i;
    reg        sensor_valid_i;

    // =========================================================================
    // RF INPUTS
    // =========================================================================

    reg [7:0] rssi_dbm_i;
    reg       link_up_i;
    reg       link_error_i;
    reg       carrier_detect_i;

    wire rf_enable_o;

    // =========================================================================
    // GPIO
    // =========================================================================

    wire [GPIO_WIDTH-1:0] gpio_out;
    wire [GPIO_WIDTH-1:0] gpio_oe;

    reg  [GPIO_WIDTH-1:0] gpio_in;

    // =========================================================================
    // VGA / VDP
    // =========================================================================

    wire       hsync_o;
    wire       vsync_o;

    wire [11:0] pixel_x_o;
    wire [11:0] pixel_y_o;

    wire [3:0] rgb_r_o;
    wire [3:0] rgb_g_o;
    wire [3:0] rgb_b_o;

    // =========================================================================
    // CPU STATUS
    // =========================================================================

    wire trap;

    // =========================================================================
    // DUT
    // =========================================================================

    cpu_soc_ram_top #(
        .ADDR_WIDTH     (32),
        .DATA_WIDTH     (DATA_WIDTH),
        .RAM_ADDR_WIDTH (16),
        .RAM_DEPTH      (RAM_DEPTH),
        .GPIO_WIDTH     (GPIO_WIDTH)
    ) dut (
        .clk                    (clk),
        .resetn                 (resetn),

        .battery_percent_i      (battery_percent_i),
        .battery_voltage_mv_i   (battery_voltage_mv_i),
        .temperature_tenthsC_i  (temperature_tenthsC_i),
        .sensor_valid_i         (sensor_valid_i),

        .rssi_dbm_i             (rssi_dbm_i),
        .link_up_i              (link_up_i),
        .link_error_i           (link_error_i),
        .carrier_detect_i       (carrier_detect_i),

        .rf_enable_o            (rf_enable_o),

        .gpio_out               (gpio_out),
        .gpio_oe                (gpio_oe),
        .gpio_in                (gpio_in),

        .pixel_clk              (pixel_clk),

        .hsync_o                (hsync_o),
        .vsync_o                (vsync_o),

        .pixel_x_o              (pixel_x_o),
        .pixel_y_o              (pixel_y_o),

        .rgb_r_o                (rgb_r_o),
        .rgb_g_o                (rgb_g_o),
        .rgb_b_o                (rgb_b_o),

        .trap                   (trap)
    );

    // =========================================================================
    // CLOCK GENERATION
    // =========================================================================

    initial begin
        clk = 1'b0;

        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    initial begin
        pixel_clk = 1'b0;

        forever #(PIXEL_CLK_PERIOD / 2)
            pixel_clk = ~pixel_clk;
    end

    // =========================================================================
    // FIRMWARE LOADING
    // =========================================================================
    //
    // The RAM instance in cpu_soc_ram_top.v is named:
    //
    //     ram
    //
    // The internal memory array inside soc_ram is assumed to be named:
    //
    //     mem
    //
    // Therefore:
    //
    //     dut.ram.mem
    //
    // =========================================================================

    initial begin
        $display("====================================================");
        $display("Loading firmware...");
        $display("====================================================");

        $readmemh("firmware/firmware.hex", dut.ram.mem);

        $display("Firmware loaded successfully.");
    end

    // =========================================================================
    // INITIAL INPUT VALUES
    // =========================================================================

    initial begin
        battery_percent_i     = 8'd85;
        battery_voltage_mv_i  = 16'd12000;
        temperature_tenthsC_i = 16'd250;
        sensor_valid_i        = 1'b1;

        rssi_dbm_i            = 8'd70;
        link_up_i             = 1'b1;
        link_error_i          = 1'b0;
        carrier_detect_i      = 1'b1;

        gpio_in               = 32'h0000_0000;
    end

    // =========================================================================
    // RESET SEQUENCE
    // =========================================================================

    initial begin
        resetn = 1'b0;

        repeat (10) @(posedge clk);

        resetn = 1'b1;

        $display("[%0t] Reset released.", $time);
    end

    // =========================================================================
    // CPU BUS MONITOR
    // =========================================================================

    always @(posedge clk) begin
        if (resetn && dut.m_valid && dut.m_ready) begin

            if (dut.m_write) begin
                $display(
                    "[%0t] CPU WRITE: addr=%h data=%h strb=%b",
                    $time,
                    dut.m_addr,
                    dut.m_wdata,
                    dut.m_strb
                );
            end
            else begin
                $display(
                    "[%0t] CPU READ : addr=%h",
                    $time,
                    dut.m_addr
                );
            end

        end
    end

    // =========================================================================
    // TPU / NN MONITOR
    // =========================================================================
    //
    // TPU is mapped at:
    //
    //     0x0001_4000 - 0x0001_4FFF
    //
    // The TPU instance is:
    //
    //     dut.tpu
    //
    // =========================================================================

    always @(posedge clk) begin
        if (resetn && dut.nn_valid && dut.nn_ready) begin

            if (dut.nn_write) begin
                $display(
                    "[%0t] TPU WRITE: local_addr=%h data=%h strb=%b",
                    $time,
                    dut.nn_addr,
                    dut.nn_wdata,
                    dut.nn_strb
                );
            end
            else begin
                $display(
                    "[%0t] TPU READ : local_addr=%h data=%h",
                    $time,
                    dut.nn_addr,
                    dut.nn_rdata
                );
            end

        end
    end

    // =========================================================================
    // TPU RESULT MONITOR
    // =========================================================================

    always @(posedge clk) begin
        if (resetn) begin

            if ((dut.tpu.result0 !== 64'bx) ||
                (dut.tpu.result1 !== 64'bx)) begin

                $display(
                    "[%0t] TPU RESULT: result0=%h result1=%h",
                    $time,
                    dut.tpu.result0,
                    dut.tpu.result1
                );

            end

        end
    end

    // =========================================================================
    // GPIO MONITOR
    // =========================================================================

    always @(posedge clk) begin
        if (resetn) begin
            if (gpio_out !== 32'b0) begin
                $display(
                    "[%0t] GPIO OUT=%h GPIO OE=%h",
                    $time,
                    gpio_out,
                    gpio_oe
                );
            end
        end
    end

    // =========================================================================
    // RF MONITOR
    // =========================================================================

    always @(posedge clk) begin
        if (resetn) begin
            if (rf_enable_o !== 1'b0) begin
                $display(
                    "[%0t] RF ENABLE=%b",
                    $time,
                    rf_enable_o
                );
            end
        end
    end

    // =========================================================================
    // TRAP DETECTION
    // =========================================================================

    always @(posedge clk) begin
        if (trap === 1'b1) begin
            $display("====================================================");
            $display("[%0t] CPU TRAP DETECTED", $time);
            $display("====================================================");

            scan_ram_markers();

            $finish;
        end
    end

    // =========================================================================
    // RAM MARKER SCAN
    // =========================================================================

    task scan_ram_markers;

        integer i;

        begin
            $display("====================================================");
            $display("Scanning RAM for firmware markers...");
            $display("====================================================");

            for (i = 0; i < RAM_DEPTH; i = i + 1) begin

                if (dut.ram.mem[i] == 32'h1111_1111) begin
                    $display(
                        "RAM marker 0x11111111 found at word index %0d",
                        i
                    );
                end

                if (dut.ram.mem[i] == 32'h2222_2222) begin
                    $display(
                        "RAM marker 0x22222222 found at word index %0d",
                        i
                    );
                end

                if (dut.ram.mem[i] == 32'h3333_3333) begin
                    $display(
                        "RAM marker 0x33333333 found at word index %0d",
                        i
                    );
                end

                if (dut.ram.mem[i] == 32'hDEAD_0001) begin
                    $display(
                        "RAM ERROR marker 0xDEAD0001 found at word index %0d",
                        i
                    );
                end

            end

            $display("RAM marker scan completed.");
        end

    endtask

    // =========================================================================
    // TIMEOUT
    // =========================================================================

    initial begin

        repeat (TIMEOUT_CYCLES) @(posedge clk);

        $display("====================================================");
        $display("[%0t] TESTBENCH TIMEOUT", $time);
        $display("====================================================");

        scan_ram_markers();

        $finish;

    end

    // =========================================================================
    // WAVEFORM DUMP
    // =========================================================================

    initial begin
        $dumpfile("cpu_soc_ram_top.vcd");
        $dumpvars(0, tb_cpu_soc_ram_top);
    end

endmodule