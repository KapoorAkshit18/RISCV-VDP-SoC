`ifndef TB_SOC_UVM_SV
`define TB_SOC_UVM_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

import soc_uvm_pkg::*;

module tb_soc_uvm;

    // =========================================================================
    // Parameters
    // =========================================================================

    localparam int ADDR_WIDTH     = 32;
    localparam int DATA_WIDTH     = 32;
    localparam int RAM_ADDR_WIDTH = 16;
    localparam int RAM_DEPTH      = 16384;
    localparam int GPIO_WIDTH     = 32;


    // =========================================================================
    // Clock / reset
    // =========================================================================

    logic clk;
    logic resetn;
    logic pixel_clk;


    // =========================================================================
    // Native bus interface
    // =========================================================================

    soc_native_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) native_if (
        .clk    (clk)
        //.resetn (resetn)
    );


    // =========================================================================
    // External GPIO
    // =========================================================================

    logic [GPIO_WIDTH-1:0] gpio_in;
    wire  [GPIO_WIDTH-1:0] gpio_out;
    wire  [GPIO_WIDTH-1:0] gpio_oe;


    // =========================================================================
    // Sensor
    // =========================================================================

    logic [7:0]  battery_percent_i;
    logic [15:0] battery_voltage_mv_i;
    logic [15:0] temperature_tenthsC_i;
    logic        sensor_valid_i;


    // =========================================================================
    // RF
    // =========================================================================

    logic [7:0] rssi_dbm_i;
    logic       link_up_i;
    logic       link_error_i;
    logic       carrier_detect_i;

    wire rf_enable_o;


    // =========================================================================
    // VDP
    // =========================================================================

    wire        hsync_o;
    wire        vsync_o;

    wire [11:0] pixel_x_o;
    wire [11:0] pixel_y_o;

    wire [3:0] rgb_r_o;
    wire [3:0] rgb_g_o;
    wire [3:0] rgb_b_o;


    // =========================================================================
    // Clock generation
    // =========================================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        pixel_clk = 1'b0;
        forever #10 pixel_clk = ~pixel_clk;
    end


    // =========================================================================
    // Reset
    // =========================================================================

    initial begin

        resetn = 1'b0;

        repeat (5)
            @(posedge clk);

        resetn = 1'b1;

        `uvm_info(
            "TB",
            "System reset released",
            UVM_LOW
        )

    end


    // =========================================================================
    // Default inputs
    // =========================================================================

    initial begin

        gpio_in = '0;

        battery_percent_i     = 8'd85;
        battery_voltage_mv_i  = 16'd3700;
        temperature_tenthsC_i = 16'd250;
        sensor_valid_i        = 1'b1;

        rssi_dbm_i       = 8'hD8;
        link_up_i        = 1'b1;
        link_error_i     = 1'b0;
        carrier_detect_i = 1'b1;

    end


    // =========================================================================
    // DUT
    // =========================================================================

    soc_uvm_dut #(
        .ADDR_WIDTH     (ADDR_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH),
        .RAM_ADDR_WIDTH (RAM_ADDR_WIDTH),
        .RAM_DEPTH      (RAM_DEPTH),
        .GPIO_WIDTH     (GPIO_WIDTH)
    ) dut (

        .clk       (clk),
        .resetn    (resetn),

        .m_valid   (native_if.m_valid),
        .m_write   (native_if.m_write),
        .m_addr    (native_if.m_addr),
        .m_wdata   (native_if.m_wdata),
        .m_strb    (native_if.m_strb),

        .m_ready   (native_if.m_ready),
        .m_rdata   (native_if.m_rdata),

        .gpio_in   (gpio_in),
        .gpio_out  (gpio_out),
        .gpio_oe   (gpio_oe),

        .battery_percent_i     (battery_percent_i),
        .battery_voltage_mv_i  (battery_voltage_mv_i),
        .temperature_tenthsC_i(temperature_tenthsC_i),
        .sensor_valid_i        (sensor_valid_i),

        .rssi_dbm_i       (rssi_dbm_i),
        .link_up_i        (link_up_i),
        .link_error_i     (link_error_i),
        .carrier_detect_i (carrier_detect_i),

        .rf_enable_o      (rf_enable_o),

        .pixel_clk (pixel_clk),

        .hsync_o   (hsync_o),
        .vsync_o   (vsync_o),

        .pixel_x_o (pixel_x_o),
        .pixel_y_o (pixel_y_o),

        .rgb_r_o   (rgb_r_o),
        .rgb_g_o   (rgb_g_o),
        .rgb_b_o   (rgb_b_o)

    );


    // =========================================================================
    // UVM configuration
    // =========================================================================

    initial begin

        uvm_config_db#(virtual soc_native_if)::set(
            null,
            "*",
            "vif",
            native_if
        );

    end


    // =========================================================================
    // Start UVM
    // =========================================================================

    // initial begin

    //     run_test("soc_smoke_test");

    // end


    // =========================================================================
    // Waveform
    // =========================================================================

    initial begin

        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_soc_uvm);

    end

endmodule

`endif