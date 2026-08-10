`timescale 1ns/1ps

// =============================================================================
// soc_mem_interconnect.v
//
// Rev 1.0 PicoRV32 native memory interconnect.
//
// System address map:
//
//   0x0000_0000 - 0x0000_FFFF : 64-KB RAM
//
//   0x0001_0000 - 0x0001_0FFF : GPIO
//   0x0001_1000 - 0x0001_1FFF : RF
//   0x0001_2000 - 0x0001_2FFF : Sensor
//   0x0001_3000 - 0x0001_3FFF : VDP
//
// All peripheral windows are 4 KB.
//
// System/master address:
//   m_addr       = 32 bits
//
// Peripheral local addresses:
//   gpio_addr    = 12 bits
//   rf_addr      = 12 bits
//   sensor_addr  = 12 bits
//   vdp_addr     = 12 bits
//
// Native-bus convention:
//   m_valid = 1                  -> request valid
//   m_write = 1                  -> write
//   m_write = 0                  -> read
//   m_strb  = 0000               -> read
//   m_strb != 0000               -> write
//
// No AXI logic is present in this module.
//
// Unmapped accesses:
//   m_ready = 1
//   m_rdata = 0
//
// The interconnect itself is combinational. Transaction latency is provided
// by the selected slave.
//
// =============================================================================

module soc_mem_interconnect #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    // =========================================================================
    // Master side - PicoRV32 native memory interface
    // =========================================================================
    input  wire                     m_valid,
    input  wire                     m_write,
    input  wire [ADDR_WIDTH-1:0]    m_addr,
    input  wire [DATA_WIDTH-1:0]    m_wdata,
    input  wire [DATA_WIDTH/8-1:0]  m_strb,

    output reg                      m_ready,
    output reg  [DATA_WIDTH-1:0]    m_rdata,


    // =========================================================================
    // RAM slave
    //
    // RAM keeps the existing 32-bit address interface.
    // =========================================================================
    output reg                      ram_valid,
    output reg                      ram_write,
    output reg  [ADDR_WIDTH-1:0]    ram_addr,
    output reg  [DATA_WIDTH-1:0]    ram_wdata,
    output reg  [DATA_WIDTH/8-1:0]  ram_strb,

    input  wire                     ram_ready,
    input  wire [DATA_WIDTH-1:0]     ram_rdata,


    // =========================================================================
    // GPIO native slave
    //
    // 4-KB local address space -> 12-bit address.
    // =========================================================================
    output reg                      gpio_valid,
    output reg                      gpio_write,
    output reg  [11:0]              gpio_addr,
    output reg  [DATA_WIDTH-1:0]    gpio_wdata,
    output reg  [DATA_WIDTH/8-1:0]  gpio_strb,

    input  wire                     gpio_ready,
    input  wire [DATA_WIDTH-1:0]     gpio_rdata,


    // =========================================================================
    // RF native slave
    //
    // 4-KB local address space -> 12-bit address.
    // =========================================================================
    output reg                      rf_valid,
    output reg                      rf_write,
    output reg  [11:0]              rf_addr,
    output reg  [DATA_WIDTH-1:0]    rf_wdata,
    output reg  [DATA_WIDTH/8-1:0]  rf_strb,

    input  wire                     rf_ready,
    input wire  [DATA_WIDTH-1:0]    rf_rdata,


    // =========================================================================
    // Sensor native slave
    //
    // 4-KB local address space -> 12-bit address.
    // =========================================================================
    output reg                      sensor_valid,
    output reg                      sensor_write,
    output reg  [11:0]              sensor_addr,
    output reg  [DATA_WIDTH-1:0]    sensor_wdata,
    output reg  [DATA_WIDTH/8-1:0]  sensor_strb,

    input  wire                     sensor_ready,
    input wire  [DATA_WIDTH-1:0]    sensor_rdata,


    // =========================================================================
    // VDP native slave
    //
    // 4-KB local address space -> 12-bit address.
    //
    // pixel_clk and VGA signals are NOT handled by the interconnect.
    // VDP internally handles its own pixel-clock domain.
    // =========================================================================
    output reg                      vdp_valid,
    output reg                      vdp_write,
    output reg  [11:0]              vdp_addr,
    output reg  [DATA_WIDTH-1:0]    vdp_wdata,
    output reg  [DATA_WIDTH/8-1:0]  vdp_strb,

    input  wire                     vdp_ready,
    input wire  [DATA_WIDTH-1:0]    vdp_rdata

);


    // =========================================================================
    // Address map
    // =========================================================================

    // 64-KB RAM
    localparam [ADDR_WIDTH-1:0] RAM_BASE =
                                      32'h0000_0000;

    localparam [ADDR_WIDTH-1:0] RAM_MASK =
                                      32'hFFFF_0000;


    // 4-KB GPIO window
    localparam [ADDR_WIDTH-1:0] GPIO_BASE =
                                      32'h0001_0000;


    // 4-KB RF window
    localparam [ADDR_WIDTH-1:0] RF_BASE =
                                      32'h0001_1000;


    // 4-KB Sensor window
    localparam [ADDR_WIDTH-1:0] SENSOR_BASE =
                                      32'h0001_2000;


    // 4-KB VDP window
    localparam [ADDR_WIDTH-1:0] VDP_BASE =
                                      32'h0001_3000;


    // All peripheral windows are 4 KB.
    localparam [ADDR_WIDTH-1:0] PERIPH_MASK =
                                      32'hFFFF_F000;


    // =========================================================================
    // Address decode signals
    // =========================================================================

    wire ram_sel;
    wire gpio_sel;
    wire rf_sel;
    wire sensor_sel;
    wire vdp_sel;


    assign ram_sel =
        ((m_addr & RAM_MASK) == RAM_BASE);


    assign gpio_sel =
        ((m_addr & PERIPH_MASK) == GPIO_BASE);


    assign rf_sel =
        ((m_addr & PERIPH_MASK) == RF_BASE);


    assign sensor_sel =
        ((m_addr & PERIPH_MASK) == SENSOR_BASE);


    assign vdp_sel =
        ((m_addr & PERIPH_MASK) == VDP_BASE);


    // =========================================================================
    // Combinational routing
    // =========================================================================

    always @(*) begin

        // ---------------------------------------------------------------------
        // Master response defaults
        // ---------------------------------------------------------------------

        m_ready = 1'b0;
        m_rdata = {DATA_WIDTH{1'b0}};


        // ---------------------------------------------------------------------
        // RAM defaults
        // ---------------------------------------------------------------------

        ram_valid = 1'b0;
        ram_write = 1'b0;
        ram_addr  = {ADDR_WIDTH{1'b0}};
        ram_wdata = {DATA_WIDTH{1'b0}};
        ram_strb  = {(DATA_WIDTH/8){1'b0}};


        // ---------------------------------------------------------------------
        // GPIO defaults
        // ---------------------------------------------------------------------

        gpio_valid = 1'b0;
        gpio_write = 1'b0;
        gpio_addr  = 12'h000;
        gpio_wdata = {DATA_WIDTH{1'b0}};
        gpio_strb  = {(DATA_WIDTH/8){1'b0}};


        // ---------------------------------------------------------------------
        // RF defaults
        // ---------------------------------------------------------------------

        rf_valid = 1'b0;
        rf_write = 1'b0;
        rf_addr  = 12'h000;
        rf_wdata = {DATA_WIDTH{1'b0}};
        rf_strb  = {(DATA_WIDTH/8){1'b0}};


        // ---------------------------------------------------------------------
        // Sensor defaults
        // ---------------------------------------------------------------------

        sensor_valid = 1'b0;
        sensor_write = 1'b0;
        sensor_addr  = 12'h000;
        sensor_wdata = {DATA_WIDTH{1'b0}};
        sensor_strb  = {(DATA_WIDTH/8){1'b0}};


        // ---------------------------------------------------------------------
        // VDP defaults
        // ---------------------------------------------------------------------

        vdp_valid = 1'b0;
        vdp_write = 1'b0;
        vdp_addr  = 12'h000;
        vdp_wdata = {DATA_WIDTH{1'b0}};
        vdp_strb  = {(DATA_WIDTH/8){1'b0}};


        // =====================================================================
        // Address decode and routing
        // =====================================================================

        if (m_valid) begin

            // -----------------------------------------------------------------
            // RAM
            // -----------------------------------------------------------------
            if (ram_sel) begin

                ram_valid = 1'b1;
                ram_write = m_write;

                // RAM receives the complete system address.
                ram_addr  = m_addr;

                ram_wdata = m_wdata;
                ram_strb  = m_strb;

                m_ready   = ram_ready;
                m_rdata   = ram_rdata;

            end


            // -----------------------------------------------------------------
            // GPIO
            // -----------------------------------------------------------------
            else if (gpio_sel) begin

                gpio_valid = 1'b1;
                gpio_write = m_write;

                // Convert system address into 12-bit GPIO-local address.
                gpio_addr  = m_addr[11:0];

                gpio_wdata = m_wdata;
                gpio_strb  = m_strb;

                m_ready    = gpio_ready;
                m_rdata    = gpio_rdata;

            end


            // -----------------------------------------------------------------
            // RF
            // -----------------------------------------------------------------
            else if (rf_sel) begin

                rf_valid = 1'b1;
                rf_write = m_write;

                // Convert system address into 12-bit RF-local address.
                rf_addr  = m_addr[11:0];

                rf_wdata = m_wdata;
                rf_strb  = m_strb;

                m_ready  = rf_ready;
                m_rdata  = rf_rdata;

            end


            // -----------------------------------------------------------------
            // Sensor
            // -----------------------------------------------------------------
            else if (sensor_sel) begin

                sensor_valid = 1'b1;
                sensor_write = m_write;

                // Convert system address into 12-bit Sensor-local address.
                sensor_addr  = m_addr[11:0];

                sensor_wdata = m_wdata;
                sensor_strb  = m_strb;

                m_ready      = sensor_ready;
                m_rdata      = sensor_rdata;

            end


            // -----------------------------------------------------------------
            // VDP
            // -----------------------------------------------------------------
            else if (vdp_sel) begin

                vdp_valid = 1'b1;
                vdp_write = m_write;

                // Convert system address into 12-bit VDP-local address.
                vdp_addr  = m_addr[11:0];

                vdp_wdata = m_wdata;
                vdp_strb  = m_strb;

                m_ready   = vdp_ready;
                m_rdata   = vdp_rdata;

            end


            // -----------------------------------------------------------------
            // Unmapped address
            //
            // Native PicoRV32 bus has no SLVERR.
            //
            // Complete the transaction with zero data.
            // -----------------------------------------------------------------
            else begin

                m_ready = 1'b1;
                m_rdata = {DATA_WIDTH{1'b0}};

            end

        end

    end

endmodule
