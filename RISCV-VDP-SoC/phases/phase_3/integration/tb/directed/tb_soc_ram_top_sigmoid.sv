`timescale 1ns/1ps

module tb_soc_ram_top;

    // ================================================================
    // DUT signals
    // Keep your existing declarations/connections here
    // ================================================================


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


    // ================================================================
    // Firmware / debug parameters
    // ================================================================

    localparam [31:0] SIG_BASE    = 32'h0000_1340;
    localparam [31:0] RESULT_BASE = 32'h0000_1350;

    localparam integer SIG_RAM_INDEX    = 32'h1340 >> 2;
    localparam integer RESULT_RAM_INDEX = 32'h1350 >> 2;

    localparam integer SIG_WORDS    = 2;
    localparam integer RESULT_WORDS = 2;

    localparam [31:0] WORKLOAD_DONE = 32'h2222_2222;
    localparam [31:0] BENCH_DONE    = 32'h3333_3333;
    localparam [31:0] VERIFY_FAIL   = 32'hDEAD_0001;

    localparam [31:0] WORKLOAD_DONE = 32'h2222_2222;
    localparam [31:0] VERIFY_FAIL   = 32'hDEAD_0001;
    localparam [31:0] BENCH_DONE    = 32'h3333_3333;

    // 100 MHz clock => 10 ns/cycle
    //
    // This is NOT the expected execution time.
    // It is only a safety timeout.
    //
    // 100000 cycles = 1 ms.
    localparam integer TIMEOUT_CYCLES = 100000;


    // ================================================================
    // Debug state
    // ================================================================

    integer i;
    integer errors;
    integer cycle_count;

    integer output_write_count;
    integer output_read_count;

    reg workload_done;
    reg verification_failed;
    reg benchmark_done;
    reg simulation_timeout;


    // ================================================================
    // Clock
    // ================================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // ================================================================
    // Pixel clock
    // Keep it because Phase 3 has it, although it is not relevant
    // to this pre-TPU firmware debug.
    // ================================================================

    initial begin
        pixel_clk = 1'b0;
        forever #20 pixel_clk = ~pixel_clk;
    end


    // ================================================================
    // Firmware
    // ================================================================

    initial begin
        $display("");
        $display("==============================================");
        $display("PHASE 3 PRE-TPU FIRMWARE DEBUG");
        $display("==============================================");

        $display("Loading firmware_new.hex ...");

        $readmemh(
            "../../firmware_test3/firmware_3.hex",
            dut.ram.mem
        );

        $display("Firmware loaded.");
        $display("");
    end


    // ================================================================
    // Initial state
    // ================================================================

    initial begin

        errors              = 0;
        cycle_count         = 0;

        output_write_count  = 0;
        output_read_count   = 0;

        workload_done       = 1'b0;
        verification_failed = 1'b0;
        benchmark_done      = 1'b0;
        simulation_timeout  = 1'b0;

        resetn = 1'b0;

        // Keep your other existing TB inputs here.
        // Example:
        //
        // gpio_in = 0;
        // sensor_data = ...;
        // rssi_dbm = ...;
        //
        // Do NOT change them dynamically during this debug.
    end


    // ================================================================
    // CPU BUS MONITOR
    //
    // This is the most important monitor.
    //
    // Only print a transaction when valid AND ready are both high.
    // That represents a completed bus transaction.
    // ================================================================

    always @(posedge clk) begin

        if (dut.m_valid && dut.m_ready) begin

            // --------------------------------------------------------
            // WRITE
            // --------------------------------------------------------

            if (dut.m_write) begin

                $display(
                    "CPU WRITE: time=%0t addr=%08h wdata=%08h strb=%h",
                    $time,
                    dut.m_addr,
                    dut.m_wdata,
                    dut.m_strb
                );


                // ----------------------------------------------------
                // OUTPUT ARRAY WRITE
                //
                // 0x1220 -> output[0]
                // 0x1224 -> output[1]
                // ...
                // 0x129C -> output[31]
                // ----------------------------------------------------

                if ((dut.m_addr >= OUTPUT_BASE) &&
                    (dut.m_addr <= OUTPUT_LAST)) begin

                    output_write_count =
                        output_write_count + 1;

                    $display(
                        "    >>> OUTPUT WRITE: output[%0d] addr=%08h data=%08h",
                        (dut.m_addr - OUTPUT_BASE) >> 2,
                        dut.m_addr,
                        dut.m_wdata
                    );

                end


                // ----------------------------------------------------
                // DEBUG MARKERS
                //
                // Your firmware uses these to indicate progress.
                // ----------------------------------------------------

                if (dut.m_wdata == WORKLOAD_DONE) begin

                    workload_done = 1'b1;

                    $display("");
                    $display("==============================================");
                    $display("WORKLOAD COMPLETE: 0x22222222");
                    $display("Output writes observed = %0d",
                             output_write_count);
                    $display("==============================================");
                    $display("");

                end


                if (dut.m_wdata == VERIFY_FAIL) begin

                    verification_failed = 1'b1;

                    $display("");
                    $display("==============================================");
                    $display("VERIFICATION FAILED: 0xDEAD0001");
                    $display("==============================================");
                    $display("");

                end


                if (dut.m_wdata == BENCH_DONE) begin

                    benchmark_done = 1'b1;

                    $display("");
                    $display("==============================================");
                    $display("BENCHMARK COMPLETE: 0x33333333");
                    $display("==============================================");
                    $display("");

                end

            end


            // --------------------------------------------------------
            // READ
            // --------------------------------------------------------

            else begin

                $display(
                    "CPU READ : time=%0t addr=%08h rdata=%08h",
                    $time,
                    dut.m_addr,
                    dut.m_rdata
                );


                // ----------------------------------------------------
                // OUTPUT ARRAY READ
                // ----------------------------------------------------

                if ((dut.m_addr >= OUTPUT_BASE) &&
                    (dut.m_addr <= OUTPUT_LAST)) begin

                    output_read_count =
                        output_read_count + 1;

                    $display(
                        "    <<< OUTPUT READ: output[%0d] addr=%08h data=%08h",
                        (dut.m_addr - OUTPUT_BASE) >> 2,
                        dut.m_addr,
                        dut.m_rdata
                    );

                end

            end

        end

    end


    // ================================================================
    // RAM SIDE MONITOR
    //
    // This tells us whether the CPU transaction actually reaches RAM.
    // ================================================================

    always @(posedge clk) begin

        if (dut.ram_valid && dut.ram_ready) begin

            if (dut.ram_write) begin

                $display(
                    "RAM WRITE: time=%0t addr=%08h index=%0d data=%08h strb=%h",
                    $time,
                    dut.ram_addr,
                    dut.ram_addr >> 2,
                    dut.ram_wdata,
                    dut.ram_strb
                );

            end
            else begin

                $display(
                    "RAM READ : time=%0t addr=%08h index=%0d data=%08h",
                    $time,
                    dut.ram_addr,
                    dut.ram_addr >> 2,
                    dut.ram_rdata
                );

            end

        end

    end


    // ================================================================
    // CPU CYCLE COUNTER
    // ================================================================

    always @(posedge clk) begin

        if (!resetn)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;

    end


    // ================================================================
    // RESET / MAIN TEST
    // ================================================================

    initial begin

        // Hold reset initially
        resetn = 1'b0;

        // Give reset some real clock cycles.
        repeat (10) @(posedge clk);

        resetn = 1'b1;

        $display("");
        $display("RESET RELEASED");
        $display("Waiting for firmware...");
        $display("Timeout = %0d CPU cycles", TIMEOUT_CYCLES);
        $display("");

        // ------------------------------------------------------------
        // DO NOT use:
        //
        // repeat(20)
        // repeat(50)
        //
        // The firmware workload is much longer than this.
        //
        // Instead wait for a firmware marker.
        // ------------------------------------------------------------

        fork : FIRMWARE_WAIT

            begin

                wait (
                    workload_done       ||
                    verification_failed ||
                    benchmark_done      ||
                    dut.trap
                );

            end


            begin

                repeat (TIMEOUT_CYCLES)
                    @(posedge clk);

                simulation_timeout = 1'b1;

            end

        join_any

        disable FIRMWARE_WAIT;


        // ============================================================
        // TIMEOUT
        // ============================================================

        if (simulation_timeout) begin

            $display("");
            $display("==============================================");
            $display("TIMEOUT");
            $display("==============================================");
            $display(
                "Firmware did not reach a terminal marker."
            );
            $display(
                "Cycles executed = %0d",
                cycle_count
            );
            $display("");
            $display(
                "Output writes observed = %0d",
                output_write_count
            );
            $display(
                "Output reads observed  = %0d",
                output_read_count
            );
            $display("");

            $finish;
        end


        // ============================================================
        // WORKLOAD COMPLETED
        // ============================================================

        if (workload_done) begin

            $display("");
            $display("==============================================");
            $display("CHECKING OUTPUT RAM");
            $display("==============================================");

            errors = 0;

            for (i = 0; i < 32; i = i + 1) begin

                $display(
                    "output[%0d] addr=%08hmem[%0d]=%08h expected=%08h",
                    i,
                    OUTPUT_BASE + (i * 4),
                    OUTPUT_RAM_INDEX + i,
                    dut.ram.mem[OUTPUT_RAM_INDEX + i],
                    (i + 1) * 273
                );


                if (dut.ram.mem[OUTPUT_RAM_INDEX + i] !==
                    ((i + 1) * 273)) begin

                    errors = errors + 1;

                end

            end

            $display("");
            $display(
                "Output writes observed = %0d",
                output_write_count
            );

            $display(
                "Output reads observed  = %0d",
                output_read_count
            );

            $display(
                "Incorrect output values  = %0d",
                errors
            );

            $display("==============================================");
            $display("");


            // --------------------------------------------------------
            // If output RAM is already wrong, stop here.
            // This is exactly the failure we are investigating.
            // --------------------------------------------------------

            if (errors != 0) begin

                $display("");
                $display("FAIL: Output RAM contents are incorrect.");
                $display(
                    "Now inspect CPU WRITE -> RAM WRITE path."
                );
                $display("");

                $finish;

            end


            // --------------------------------------------------------
            // All outputs correct.
            // Wait for final firmware marker.
            // --------------------------------------------------------

            $display("");
            $display("All 32 output values are correct.");
            $display("Waiting for 0x33333333...");
            $display("");

            fork : FINAL_WAIT

                begin

                    wait (
                        benchmark_done      ||
                        verification_failed ||
                        dut.trap
                    );

                end

                begin

                    repeat (10000)
                        @(posedge clk);

                    simulation_timeout = 1'b1;

                end

            join_any

            disable FINAL_WAIT;

        end


        // ============================================================
        // FINAL RESULT
        // ============================================================

        if (benchmark_done) begin

            $display("");
            $display("==============================================");
            $display("PHASE 3 PASS");
            $display("0x33333333 received.");
            $display("==============================================");
            $display("");

        end
        else if (verification_failed) begin

            $display("");
            $display("==============================================");
            $display("PHASE 3 FAIL");
            $display("Firmware reported 0xDEAD0001.");
            $display("==============================================");
            $display("");

        end
        else if (dut.trap) begin

            $display("");
            $display("==============================================");
            $display("PHASE 3 FAIL: CPU TRAP");
            $display("==============================================");
            $display("");

        end
        else if (simulation_timeout) begin

            $display("");
            $display("==============================================");
            $display("PHASE 3 TIMEOUT");
            $display("==============================================");
            $display("");

        end

        $display("");
        $display("==============================================");

        $stop;


        $finish;

    end

endmodule