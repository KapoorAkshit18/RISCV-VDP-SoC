`ifndef SOC_UVM_DUT_SV
`define SOC_UVM_DUT_SV

`timescale 1ns/1ps

// =============================================================================
// RISCV-VDP-SoC
// UVM DUT WRAPPER
// =============================================================================
//
// Phase-1 UVM verification boundary:
//
//        UVM Native Bus Agent
//                 |
//                 v
//          soc_native_if
//                 |
//                 v
//        soc_mem_interconnect       <-- ACTUAL RTL
//          |    |    |    |    |
//          v    v    v    v    v
//         RAM GPIO  RF Sensor VDP  <-- ACTUAL RTL
//
// This file is TESTBENCH infrastructure.
// It does NOT replace or modify cpu_soc_ram_top.
//
// cpu_soc_ram_top remains the integrated SoC top used for later
// CPU/end-to-end verification.
//
// =============================================================================

module soc_uvm_dut #(
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32,
    parameter RAM_ADDR_WIDTH  = 16,
    parameter RAM_DEPTH       = 16384,
    parameter GPIO_WIDTH      = 32
)(
    input wire clk,
    input wire resetn,

    // =========================================================================
    // Native master interface driven by UVM
    // =========================================================================

    input  wire                     m_valid,
    input  wire                     m_write,
    input  wire [ADDR_WIDTH-1:0]    m_addr,
    input  wire [DATA_WIDTH-1:0]    m_wdata,
    input  wire [DATA_WIDTH/8-1:0]  m_strb,

    output wire                     m_ready,
    output wire [DATA_WIDTH-1:0]    m_rdata,

    // =========================================================================
    // GPIO
    // =========================================================================

    input  wire [GPIO_WIDTH-1:0]    gpio_in,
    output wire [GPIO_WIDTH-1:0]    gpio_out,
    output wire [GPIO_WIDTH-1:0]    gpio_oe,

    // =========================================================================
    // Sensor inputs
    // =========================================================================

    input wire [7:0]  battery_percent_i,
    input wire [15:0] battery_voltage_mv_i,
    input wire [15:0] temperature_tenthsC_i,
    input wire        sensor_valid_i,

    // =========================================================================
    // RF telemetry
    // =========================================================================

    input wire [7:0] rssi_dbm_i,
    input wire       link_up_i,
    input wire       link_error_i,
    input wire       carrier_detect_i,

    output wire      rf_enable_o,

    // =========================================================================
    // VDP
    // =========================================================================

    input wire pixel_clk,

    output wire        hsync_o,
    output wire        vsync_o,
    output wire [11:0] pixel_x_o,
    output wire [11:0] pixel_y_o,

    output wire [3:0] rgb_r_o,
    output wire [3:0] rgb_g_o,
    output wire [3:0] rgb_b_o
);


    // =========================================================================
    // Interconnect -> RAM
    // =========================================================================

    wire                     ram_valid;
    wire                     ram_write;
    wire [ADDR_WIDTH-1:0]    ram_addr;
    wire [DATA_WIDTH-1:0]    ram_wdata;
    wire [DATA_WIDTH/8-1:0]  ram_strb;

    wire                     ram_ready;
    wire [DATA_WIDTH-1:0]    ram_rdata;


    // =========================================================================
    // Interconnect -> GPIO
    // =========================================================================

    wire                     gpio_valid;
    wire                     gpio_write;
    wire [11:0]              gpio_addr;
    wire [DATA_WIDTH-1:0]    gpio_wdata;
    wire [DATA_WIDTH/8-1:0]  gpio_strb;

    wire                     gpio_ready;
    wire [DATA_WIDTH-1:0]    gpio_rdata;


    // =========================================================================
    // Interconnect -> RF
    // =========================================================================

    wire                     rf_valid;
    wire                     rf_write;
    wire [11:0]              rf_addr;
    wire [DATA_WIDTH-1:0]    rf_wdata;
    wire [DATA_WIDTH/8-1:0]  rf_strb;

    wire                     rf_ready;
    wire [DATA_WIDTH-1:0]    rf_rdata;


    // =========================================================================
    // Interconnect -> Sensor
    // =========================================================================

    wire                     sensor_valid;
    wire                     sensor_write;
    wire [11:0]              sensor_addr;
    wire [DATA_WIDTH-1:0]    sensor_wdata;
    wire [DATA_WIDTH/8-1:0]  sensor_strb;

    wire                     sensor_ready;
    wire [DATA_WIDTH-1:0]    sensor_rdata;


    // =========================================================================
    // Interconnect -> VDP
    // =========================================================================

    wire                     vdp_valid;
    wire                     vdp_write;
    wire [11:0]              vdp_addr;
    wire [DATA_WIDTH-1:0]    vdp_wdata;
    wire [DATA_WIDTH/8-1:0]  vdp_strb;

    wire                     vdp_ready;
    wire [DATA_WIDTH-1:0]    vdp_rdata;


    // =========================================================================
    // ACTUAL RTL: SOC MEMORY INTERCONNECT
    // =========================================================================

    soc_mem_interconnect #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) \interconnect (

        // ---------------------------------------------------------------------
        // Master side
        // ---------------------------------------------------------------------

        .m_valid    (m_valid),
        .m_write    (m_write),
        .m_addr     (m_addr),
        .m_wdata    (m_wdata),
        .m_strb     (m_strb),

        .m_ready    (m_ready),
        .m_rdata    (m_rdata),

        // ---------------------------------------------------------------------
        // RAM
        // ---------------------------------------------------------------------

        .ram_valid  (ram_valid),
        .ram_write  (ram_write),
        .ram_addr   (ram_addr),
        .ram_wdata  (ram_wdata),
        .ram_strb   (ram_strb),

        .ram_ready  (ram_ready),
        .ram_rdata  (ram_rdata),

        // ---------------------------------------------------------------------
        // GPIO
        // ---------------------------------------------------------------------

        .gpio_valid (gpio_valid),
        .gpio_write (gpio_write),
        .gpio_addr  (gpio_addr),
        .gpio_wdata (gpio_wdata),
        .gpio_strb  (gpio_strb),

        .gpio_ready (gpio_ready),
        .gpio_rdata (gpio_rdata),

        // ---------------------------------------------------------------------
        // RF
        // ---------------------------------------------------------------------

        .rf_valid   (rf_valid),
        .rf_write   (rf_write),
        .rf_addr    (rf_addr),
        .rf_wdata   (rf_wdata),
        .rf_strb    (rf_strb),

        .rf_ready   (rf_ready),
        .rf_rdata   (rf_rdata),

        // ---------------------------------------------------------------------
        // Sensor
        // ---------------------------------------------------------------------

        .sensor_valid (sensor_valid),
        .sensor_write (sensor_write),
        .sensor_addr  (sensor_addr),
        .sensor_wdata (sensor_wdata),
        .sensor_strb  (sensor_strb),

        .sensor_ready (sensor_ready),
        .sensor_rdata (sensor_rdata),

        // ---------------------------------------------------------------------
        // VDP
        // ---------------------------------------------------------------------

        .vdp_valid  (vdp_valid),
        .vdp_write  (vdp_write),
        .vdp_addr   (vdp_addr),
        .vdp_wdata  (vdp_wdata),
        .vdp_strb   (vdp_strb),

        .vdp_ready  (vdp_ready),
        .vdp_rdata  (vdp_rdata)
    );


    // =========================================================================
    // ACTUAL RTL: RAM
    // =========================================================================

    soc_ram #(
        .ADDR_WIDTH (RAM_ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (RAM_DEPTH)
    ) ram (

        .clk    (clk),
        .reset  (~resetn),

        .valid  (ram_valid),
        .write  (ram_write),
        .addr   (ram_addr[RAM_ADDR_WIDTH-1:0]),
        .wdata  (ram_wdata),
        .strb   (ram_strb),

        .ready  (ram_ready),
        .rdata  (ram_rdata)
    );


    // =========================================================================
    // ACTUAL RTL: GPIO
    // =========================================================================

    gpio_native_slave #(
        .GPIO_WIDTH (GPIO_WIDTH)
    ) gpio (

        .clk       (clk),
        .resetn    (resetn),

        .mem_valid (gpio_valid),
        .mem_instr (1'b0),
        .mem_ready (gpio_ready),

        .mem_addr  (gpio_addr),
        .mem_wdata (gpio_wdata),
        .mem_wstrb (gpio_strb),
        .mem_rdata (gpio_rdata),

        .gpio_out  (gpio_out),
        .gpio_oe   (gpio_oe),
        .gpio_in   (gpio_in)
    );


    // =========================================================================
    // ACTUAL RTL: RF TELEMETRY
    // =========================================================================

    rf_telemetry_native_slave #(
        .ADDR_WIDTH (12),
        .DATA_WIDTH (DATA_WIDTH)
    ) rf (

        .clk              (clk),
        .resetn            (resetn),

        .mem_valid        (rf_valid),
        .mem_instr        (1'b0),
        .mem_ready        (rf_ready),

        .mem_addr         (rf_addr),
        .mem_wdata        (rf_wdata),
        .mem_wstrb        (rf_strb),
        .mem_rdata        (rf_rdata),

        .rssi_dbm_i       (rssi_dbm_i),
        .link_up_i        (link_up_i),
        .link_error_i     (link_error_i),
        .carrier_detect_i (carrier_detect_i),

        .rf_enable_o      (rf_enable_o)
    );


    // =========================================================================
    // ACTUAL RTL: SENSOR
    // =========================================================================

    sensor_status_native_slave sensor (

        .clk                   (clk),
        .resetn                (resetn),

        .mem_valid             (sensor_valid),
        .mem_instr             (1'b0),
        .mem_ready             (sensor_ready),

        .mem_addr              (sensor_addr),
        .mem_wdata             (sensor_wdata),
        .mem_wstrb             (sensor_strb),
        .mem_rdata             (sensor_rdata),

        .battery_percent_i     (battery_percent_i),
        .battery_voltage_mv_i  (battery_voltage_mv_i),
        .temperature_tenthsC_i (temperature_tenthsC_i),
        .sensor_valid_i        (sensor_valid_i)
    );


    // =========================================================================
    // ACTUAL RTL: VDP
    // =========================================================================

    vdp_native_slave vdp (

        .clk        (clk),
        .resetn     (resetn),

        .mem_valid  (vdp_valid),
        .mem_instr  (1'b0),
        .mem_ready  (vdp_ready),

        .mem_addr   (vdp_addr),
        .mem_wdata  (vdp_wdata),
        .mem_wstrb  (vdp_strb),
        .mem_rdata  (vdp_rdata),

        .pixel_clk  (pixel_clk),

        .hsync_o    (hsync_o),
        .vsync_o    (vsync_o),

        .pixel_x_o  (pixel_x_o),
        .pixel_y_o  (pixel_y_o),

        .rgb_r_o    (rgb_r_o),
        .rgb_g_o    (rgb_g_o),
        .rgb_b_o    (rgb_b_o)
    );


endmodule

`endif