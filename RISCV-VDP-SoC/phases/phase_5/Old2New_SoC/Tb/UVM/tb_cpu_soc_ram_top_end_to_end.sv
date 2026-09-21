`ifndef TB_SOC_UVM_SV_E2E
`define TB_SOC_UVM_SV_E2E

`timescale 1ns / 1ps

// =============================================================================
// RISCV-VDP-SoC
// PHASE 5 UVM END-TO-END TESTBENCH TOP
//
// Purpose:
//   HDL-only simulation wrapper for the UVM verification environment.
//
// Responsibilities of this module:
//   1. Generate clocks
//   2. Generate/reset DUT
//   3. Instantiate DUT
//   4. Instantiate verification interfaces
//   5. Connect DUT signals to interfaces
//   6. Load firmware
//   7. Configure UVM virtual interfaces
//   8. Start UVM
//   9. Generate waveform
//
// UVM responsibilities:
//   - Native-bus monitoring
//   - TPU monitoring
//   - Firmware marker detection
//   - Scoreboarding
//   - TPU reference model
//   - Functional coverage
//   - Test sequencing
//   - Timeout handling
//   - Final pass/fail reporting
//
// IMPORTANT:
//   This top intentionally contains NO procedural verification monitors,
//   counters, $finish conditions, scoreboard logic, or UVM phase control.
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"

import soc_uvm_pkg::*;

`include "soc_native_if.sv"
`include "tpu_debug_if.sv"




// =============================================================================
// TOP MODULE
// =============================================================================

module tb_cpu_soc_ram_top;

    // =========================================================================
    // PARAMETERS
    // =========================================================================

    localparam int ADDR_WIDTH     = 32;
    localparam int DATA_WIDTH     = 32;
    localparam int RAM_ADDR_WIDTH = 16;
    localparam int RAM_DEPTH      = 16384;
    localparam int GPIO_WIDTH     = 32;


    // =========================================================================
    // CLOCK / RESET
    // =========================================================================

    logic clk;
    logic pixel_clk;
    logic resetn;


    // =========================================================================
    // DUT INPUTS
    // =========================================================================

    logic [7:0]  battery_percent_i;
    logic [15:0] battery_voltage_mv_i;
    // logic [15:0] temperature_tenthsC_i;/
    logic        sensor_valid_i;

    logic [7:0]  rssi_dbm_i;
    logic        link_up_i;
    logic        link_error_i;
    logic        carrier_detect_i;

    logic [31:0] gpio_in;


    // =========================================================================
    // DUT OUTPUTS
    // =========================================================================

    logic        rf_enable_o;

    logic [31:0] gpio_out;
    logic [31:0] gpio_oe;

    logic        hsync_o;
    logic        vsync_o;

    logic [11:0] pixel_x_o;
    logic [11:0] pixel_y_o;

    logic [3:0]  rgb_r_o;
    logic [3:0]  rgb_g_o;
    logic [3:0]  rgb_b_o;

    logic        trap;


    // =========================================================================
    // NATIVE BUS INTERFACE
    // =========================================================================

    soc_native_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) native_if (
        .clk(clk)
    );

    // 
    // RNM Model for sensor status only
    // 
    real temperature;
    real sensor_voltage;

    logic [11:0] adc_code;

    logic signed [15:0] temperature_tenthsC;
    logic sensor_valid;

    // RNM Chain 

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
    // TPU DEBUG / OBSERVATION INTERFACE
    //
    // This interface is passive.
    //
    // The UVM TPU monitor observes:
    //   - START
    //   - BUSY
    //   - DONE
    //   - AXI-stream input
    //   - AXI-stream output
    //   - result registers
    // =========================================================================

    tpu_debug_if tpu_if (
        .clk(clk)
    );


    // =========================================================================
    // DUT INSTANCE
    // =========================================================================

    cpu_soc_ram_top dut (
        .clk                   (clk),
        .resetn                (resetn),

        .battery_percent_i     (battery_percent_i),
        .battery_voltage_mv_i  (battery_voltage_mv_i),
        .temperature_tenthsC_i (temperature_tenthsC),
        .sensor_valid_i        (sensor_valid),

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
    // NATIVE BUS CONNECTION
    //
    // DUT -> passive UVM interface
    //
    // The interface does not drive the DUT bus.
    // It only exposes the DUT bus to the UVM monitor.
    // =========================================================================
    // CPU/SoC native bus -> passive UVM monitor
    assign native_if.m_valid = dut.m_valid;
    assign native_if.m_write = dut.m_write;
    assign native_if.m_addr  = dut.m_addr;
    assign native_if.m_wdata = dut.m_wdata;
    assign native_if.m_strb  = dut.m_strb;

    assign native_if.m_ready = dut.m_ready;
    assign native_if.m_rdata = dut.m_rdata;
    // assign native_if.resetn = resetn;


    // =========================================================================
    // TPU DEBUG CONNECTION
    //
    // DUT -> passive TPU observation interface
    // =========================================================================

    assign tpu_if.axis_start = dut.tpu.axis_start;
    assign tpu_if.axis_busy  = dut.tpu.axis_busy;
    assign tpu_if.axis_done  = dut.tpu.axis_done;

    assign tpu_if.in_tvalid  = dut.tpu.in_tvalid;
    assign tpu_if.in_tready  = dut.tpu.in_tready;
    assign tpu_if.in_tdata   = dut.tpu.in_tdata;
    assign tpu_if.in_tlast   = dut.tpu.in_tlast;

    assign tpu_if.out_tvalid = dut.tpu.out_tvalid;
    assign tpu_if.out_tready = dut.tpu.out_tready;
    assign tpu_if.out_tdata  = dut.tpu.out_tdata;
    assign tpu_if.out_tlast  = dut.tpu.out_tlast;

    assign tpu_if.result0    = dut.tpu.result0;
    assign tpu_if.result1    = dut.tpu.result1;

    // assign tpu_if.trap       = trap;


    // =========================================================================
    // CLOCK GENERATION
    // =========================================================================

    initial begin
        clk = 1'b0;

        forever begin
            #5 clk = ~clk;
        end
    end


    // =========================================================================
    // PIXEL CLOCK GENERATION
    //
    // 25 MHz equivalent:
    //   period = 40 ns
    //   half period = 20 ns
    // =========================================================================

    initial begin
        pixel_clk = 1'b0;

        forever begin
            #20 pixel_clk = ~pixel_clk;
        end
    end


    // =========================================================================
    // DUT INPUT INITIALIZATION
    //
    // These are environment stimulus values.
    // They are not verification transactions.
    // =========================================================================

    initial begin

        battery_percent_i     = 8'd80;
        battery_voltage_mv_i  = 16'd3700;
        // temperature_tenthsC_i = 16'd250;
        temperature = 79.9;
        sensor_valid_i        = 1'b1;
        rssi_dbm_i            = 8'd50;
        link_up_i             = 1'b1;
        link_error_i          = 1'b0;
        carrier_detect_i      = 1'b1;

        gpio_in               = 32'd0;

    end


    // =========================================================================
    // RESET
    //
    // Reset is initially asserted.
    //
    // The UVM test is responsible for determining when the DUT should begin
    // normal execution. Therefore reset is not released before run_test().
    //
    // This avoids the previous phasing problem where:
    //
    //   reset
    //      ->
    //   firmware execution
    //      ->
    //   run_test()
    //
    // happened in the HDL initial block.
    // =========================================================================

    initial begin

        resetn = 1'b0;
        repeat (10) @(posedge clk);  // 10 clock cycles
        resetn = 1'b1;

    end


    // =========================================================================
    // FIRMWARE LOAD
    //
    // Firmware is loaded before UVM begins execution.
    //
    // This is initialization, not a UVM bus transaction.
    // =========================================================================

    initial begin

        $display("");
        $display("============================================================");
        $display("RISCV-VDP-SoC PHASE 5 UVM TESTBENCH");
        $display("============================================================");

        $display("[TB] Loading firmware...");

        $readmemh(
            "../../firmware_test03/firmware.hex",
            dut.ram.mem
        );

        $display("[TB] Firmware loaded.");
        $display("");
    end


    // =========================================================================
    // UVM VIRTUAL INTERFACE CONFIGURATION
    //
    // Keep interface configuration here.
    //
    // UVM components retrieve these interfaces in their build_phase().
    // =========================================================================

    initial begin

        // ---------------------------------------------------------------------
        // Native bus interface
        // ---------------------------------------------------------------------

        uvm_config_db#(virtual soc_native_if)::set(
            null,
            "*",
            "vif",
            native_if
        );


        // ---------------------------------------------------------------------
        // TPU observation interface
        // ---------------------------------------------------------------------

        uvm_config_db#(virtual tpu_debug_if)::set(
            null,
            "*",
            "tpu_vif",
            tpu_if
        );

    end


    // =========================================================================
    // WAVEFORM DUMP
    // =========================================================================

    initial begin

        $dumpfile("waveform_phase_5_uvm.vcd");
        $dumpvars(0, tb_cpu_soc_ram_top);

    end


    // =========================================================================
    // START UVM
    //
    // IMPORTANT:
    //
    // run_test() is the UVM simulation entry point.
    //
    // Do NOT:
    //   - release reset before this
    //   - wait for firmware before this
    //   - run procedural monitors before this
    //   - call $finish from this top
    //
    // The UVM test controls simulation through objections.
    // =========================================================================


        initial begin

    uvm_config_db#(virtual tpu_debug_if)::set(
        null,
        "uvm_test_top.env.tpu_monitor",
        "tpu_vif",
        tpu_if
    );

                uvm_config_db#(bit)::set(
        null,
        "uvm_test_top.env",
        "e2e_mode",
        1'b1
    );

        run_test("soc_e2e_test");

        end


endmodule

`endif