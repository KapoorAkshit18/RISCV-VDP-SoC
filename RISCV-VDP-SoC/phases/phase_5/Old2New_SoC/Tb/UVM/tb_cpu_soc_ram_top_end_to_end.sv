`ifndef TB_SOC_UVM_SV_E2E
`define TB_SOC_UVM_SV_E2E

`timescale 1ns / 1ps

// =============================================================================
// RISCV-VDP-SoC
// PHASE 5 UVM END-TO-END TESTBENCH TOP
//
// HDL-only wrapper: clocks, reset, DUT, interfaces, firmware load, RNM sensor
// chain, config_db setup, run_test().
//
// Plusargs (all optional):
//   +FW_HEX=<path>     firmware hex file
//   +TEMP_C=<real>     sensor temperature in degC (default 79.9)
//   +BATT=<int>        battery percent            (default 80)
//   +UVM_TESTNAME=...  overrides run_test() name
// =============================================================================

import uvm_pkg::*;
`include "uvm_macros.svh"

import soc_uvm_pkg::*;

`include "soc_native_if.sv"
`include "tpu_debug_if.sv"


module tb_cpu_soc_ram_top;
    import uvm_pkg::*;

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
    // NATIVE BUS INTERFACE (passive)
    // =========================================================================

    soc_native_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) native_if (
        .clk(clk)
    );


    // =========================================================================
    // RNM SENSOR CHAIN
    //
    // temperature (degC) -> sensor_voltage -> adc_code -> temperature_tenthsC
    // =========================================================================

        real temperature;
        real sensor_voltage;

        logic [11:0]        adc_code;
        logic signed [15:0] temperature_tenthsC;
        logic               sensor_valid;

        // Noise is off by default; pass +NOISE_ON to enable it for statistical
        // sweeps (see temp_sensor_rnm.sv, which now takes noise_en as a runtime
        // input instead of a compile-time ENABLE_NOISE parameter).
        bit noise_on;
        initial noise_on = $test$plusargs("NOISE_ON");

        temp_sensor_rnm u_temp_sensor (
            .temperature   (temperature),
            .noise_en      (noise_on),
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
    // TPU DEBUG / OBSERVATION INTERFACE (passive)
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
    // NATIVE BUS CONNECTION (DUT <-> UVM interface depending on mode)
    // =========================================================================

    string uvm_mode = "FIRMWARE";

    initial begin
        void'($value$plusargs("UVM_MODE=%s", uvm_mode));
        
        if (uvm_mode == "ACTIVE") begin
            $display("[TB] ACTIVE UVM MODE: Disabling CPU and forcing bus from native_if");
            
            // Hold CPU in reset so it does not fetch instructions or drive the bus
            // force dut.u_cpu.resetn = 1'b0; // REMOVED: This forces the global resetn net!
            
            // Force the interconnect inputs directly (avoids vopt collapsing internal nets)
            force dut.u_interconnect.m_valid = native_if.m_valid;
            force dut.u_interconnect.m_write = native_if.m_write;
            force dut.u_interconnect.m_addr  = native_if.m_addr;
            force dut.u_interconnect.m_wdata = native_if.m_wdata;
            force dut.u_interconnect.m_strb  = native_if.m_strb;
        end else begin
            $display("[TB] FIRMWARE UVM MODE: CPU drives the bus. UVM is passive.");
            
            // CPU drives interconnect; UVM interface is passive monitor
            force native_if.m_valid = dut.u_interconnect.m_valid;
            force native_if.m_write = dut.u_interconnect.m_write;
            force native_if.m_addr  = dut.u_interconnect.m_addr;
            force native_if.m_wdata = dut.u_interconnect.m_wdata;
            force native_if.m_strb  = dut.u_interconnect.m_strb;
        end
    end

    // Slave responses are always routed back to the UVM interface
    assign native_if.m_ready = dut.u_interconnect.m_ready;
    assign native_if.m_rdata = dut.u_interconnect.m_rdata;


    // =========================================================================
    // TPU DEBUG CONNECTION (DUT -> passive UVM interface)
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


    // =========================================================================
    // CLOCK GENERATION
    // =========================================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // 25 MHz pixel clock (40 ns period)
    initial begin
        pixel_clk = 1'b0;
        forever #20 pixel_clk = ~pixel_clk;
    end


    // =========================================================================
    // DUT INPUT INITIALIZATION
    //
    // Environment stimulus, not verification transactions.
    // Sensor temperature and battery can be overridden from the command line.
    // =========================================================================

    real temp_c;
    int  batt_pct;

    initial begin

        if (!$value$plusargs("TEMP_C=%f", temp_c)) temp_c   = 79.9;
        if (!$value$plusargs("BATT=%d",   batt_pct)) batt_pct = 80;

        temperature          = temp_c;

        battery_percent_i    = batt_pct[7:0];
        battery_voltage_mv_i = 16'd3700;

        rssi_dbm_i           = 8'd50;
        link_up_i            = 1'b1;
        link_error_i         = 1'b0;
        carrier_detect_i     = 1'b1;

        gpio_in              = 32'd0;

    end


    // =========================================================================
    // RESET
    //
    // Held for 10 clock cycles, then released.
    // =========================================================================

    initial begin
        resetn = 1'b0;
        repeat (10) @(posedge clk);
        resetn = 1'b1;
    end

    //grep below

            // in the TB, right after resetn is released, or once per run at time 
                        // --- CONFIG line for parse_results.py: "CONFIG,seed,temp_c,batt,noise_on"
            // --- RNMLOG line for parse_results.py: "RNMLOG,adc_code,sensor_voltage"
            initial begin
                #1; // let the RNM chain and plusarg reads settle
                $display("CONFIG,%0d,%0.4f,%0d,%0d",
                    $get_initial_random_seed(), temp_c, batt_pct, noise_on);
                $display("RNMLOG,%0d,%0.6f",
                    adc_code, sensor_voltage);
            end

            

    // =========================================================================
    // FIRMWARE LOAD
    //
    // Default path is the old one; pass +FW_HEX=<path> for the sensor image.
    // =========================================================================

    string fw_hex;

    initial begin

        if (!$value$plusargs("FW_HEX=%s", fw_hex))
            fw_hex = "../../firmware_test_04/firmware.hex";

        $display("");
        $display("============================================================");
        $display("RISCV-VDP-SoC PHASE 5 UVM TESTBENCH");
        $display("============================================================");
        $display("[TB] Loading firmware: %s", fw_hex);

        $readmemh(fw_hex, dut.ram.mem);

        $display("[TB] Firmware loaded.");
        $display("");
    end


    // =========================================================================
    // WAVEFORM DUMP
    // =========================================================================

    initial begin
        $dumpfile("waveform_phase_5_uvm.vcd");
        $dumpvars(0, tb_cpu_soc_ram_top);
    end


    // =========================================================================
    // UVM CONFIGURATION + START
    //
    // All config_db sets and run_test() are in one initial block so the sets
    // are guaranteed to complete before build_phase runs.
    // =========================================================================

    initial begin

        uvm_config_db#(virtual soc_native_if)::set(
            null, "*", "vif", native_if
        );

        uvm_config_db#(virtual tpu_debug_if)::set(
            null, "*", "tpu_vif", tpu_if
        );

        // In ACTIVE mode, UVM drives the bus natively.
        // In FIRMWARE mode, CPU drives it and UVM is passive (e2e_mode=1).
        if (uvm_mode == "ACTIVE") begin
            uvm_config_db#(bit)::set(null, "uvm_test_top.env", "e2e_mode", 1'b0);
        end else begin
            uvm_config_db#(bit)::set(null, "uvm_test_top.env", "e2e_mode", 1'b1);
        end

        run_test("soc_e2e_test");

    end

    `include "tb/soc_base_test/soc_active_tpu_corner_test.sv"
    `include "tb/soc_base_test/soc_active_sensor_corner_test.sv"
endmodule

`endif