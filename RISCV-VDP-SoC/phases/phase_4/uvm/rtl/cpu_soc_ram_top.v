`ifndef CPU_SOC_RAM_TOP_V
`define CPU_SOC_RAM_TOP_V

// =============================================================================
// cpu_soc_ram_top.v
//
// Complete PicoRV32 SoC integration:
//
//   PicoRV32
//       |
//       v
//   CPU Bus Adapter
//       |
//       v
//   SoC Memory Interconnect
//       |
//       +----> RAM
//       +----> GPIO
//       +----> RF Telemetry
//       +----> Sensor Status
//       +----> VDP / VGA
//
// System address map:
//
//   0x0000_0000 - 0x0000_FFFF : RAM
//   0x0001_0000 - 0x0001_0FFF : GPIO
//   0x0001_1000 - 0x0001_1FFF : RF
//   0x0001_2000 - 0x0001_2FFF : Sensor
//   0x0001_3000 - 0x0001_3FFF : VDP
//
// Peripheral local address width = 12 bits.
//
// =============================================================================

module cpu_soc_ram_top #(
    parameter ADDR_WIDTH     = 32,
    parameter DATA_WIDTH     = 32,
    parameter RAM_ADDR_WIDTH = 16,
    parameter RAM_DEPTH      = 16384,
    parameter GPIO_WIDTH     = 32
)(
    // =========================================================================
    // System clock/reset
    // =========================================================================
    input wire clk,
    input wire resetn,

    // =========================================================================
    // Sensor inputs
    // =========================================================================
    input wire [7:0]  battery_percent_i,
    input wire [15:0] battery_voltage_mv_i,
    input wire [15:0] temperature_tenthsC_i,
    input wire        sensor_valid_i,

    // =========================================================================
    // RF telemetry inputs
    // =========================================================================
    input wire [7:0]  rssi_dbm_i,
    input wire        link_up_i,
    input wire        link_error_i,
    input wire        carrier_detect_i,

    // RF control
    output wire       rf_enable_o,

    // =========================================================================
    // GPIO
    // =========================================================================
    output wire [GPIO_WIDTH-1:0] gpio_out,
    output wire [GPIO_WIDTH-1:0] gpio_oe,
    input  wire [GPIO_WIDTH-1:0] gpio_in,

    // =========================================================================
    // VDP / VGA
    // =========================================================================
    input wire pixel_clk,

    output wire       hsync_o,
    output wire       vsync_o,

    output wire [11:0] pixel_x_o,
    output wire [11:0] pixel_y_o,

    output wire [3:0] rgb_r_o,
    output wire [3:0] rgb_g_o,
    output wire [3:0] rgb_b_o,

    // =========================================================================
    // CPU status
    // =========================================================================
    output wire trap
);


    // =========================================================================
    // PicoRV32 native memory interface
    // =========================================================================

    wire                     mem_valid;
    wire                     mem_instr;
    wire [ADDR_WIDTH-1:0]    mem_addr;
    wire [DATA_WIDTH-1:0]    mem_wdata;
    wire [DATA_WIDTH/8-1:0]  mem_wstrb;

    wire                     mem_ready;
    wire [DATA_WIDTH-1:0]    mem_rdata;


    // =========================================================================
    // CPU bus adapter interface
    // =========================================================================

    wire                     m_valid;
    wire                     m_write;
    wire [ADDR_WIDTH-1:0]    m_addr;
    wire [DATA_WIDTH-1:0]    m_wdata;
    wire [DATA_WIDTH/8-1:0]  m_strb;

    wire                     m_ready;
    wire [DATA_WIDTH-1:0]    m_rdata;


    // =========================================================================
    // RAM interface
    // =========================================================================

    wire                     ram_valid;
    wire                     ram_write;
    wire [ADDR_WIDTH-1:0]    ram_addr;
    wire [DATA_WIDTH-1:0]    ram_wdata;
    wire [DATA_WIDTH/8-1:0]  ram_strb;

    wire                     ram_ready;
    wire [DATA_WIDTH-1:0]    ram_rdata;


    // =========================================================================
    // GPIO interface
    //
    // IMPORTANT:
    // Interconnect provides a 12-bit local peripheral address.
    // =========================================================================

    wire                     gpio_valid;
    wire                     gpio_write;
    wire [11:0]              gpio_addr;
    wire [DATA_WIDTH-1:0]    gpio_wdata;
    wire [DATA_WIDTH/8-1:0]  gpio_strb;

    wire                     gpio_ready;
    wire [DATA_WIDTH-1:0]    gpio_rdata;


    // =========================================================================
    // RF interface
    // =========================================================================

    wire                     rf_valid;
    wire                     rf_write;
    wire [11:0]              rf_addr;
    wire [DATA_WIDTH-1:0]    rf_wdata;
    wire [DATA_WIDTH/8-1:0]  rf_strb;

    wire                     rf_ready;
    wire [DATA_WIDTH-1:0]    rf_rdata;


    // =========================================================================
    // Sensor interface
    // =========================================================================

    wire                     sensor_valid;
    wire                     sensor_write;
    wire [11:0]              sensor_addr;
    wire [DATA_WIDTH-1:0]    sensor_wdata;
    wire [DATA_WIDTH/8-1:0]  sensor_strb;

    wire                     sensor_ready;
    wire [DATA_WIDTH-1:0]    sensor_rdata;


    // =========================================================================
    // VDP interface
    // =========================================================================

    wire                     vdp_valid;
    wire                     vdp_write;
    wire [11:0]              vdp_addr;
    wire [DATA_WIDTH-1:0]    vdp_wdata;
    wire [DATA_WIDTH/8-1:0]  vdp_strb;

    wire                     vdp_ready;
    wire [DATA_WIDTH-1:0]    vdp_rdata;


    // =========================================================================
    // PicoRV32
    // =========================================================================

    ptb cpu (
        .clk        (clk),
        .resetn     (resetn),

        .mem_ready  (mem_ready),
        .mem_rdata  (mem_rdata),

        .trap       (trap),

        .mem_valid  (mem_valid),
        .mem_instr  (mem_instr),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb)
    );


    // =========================================================================
    // CPU -> Native Bus Adapter
    // =========================================================================

    cpu_bus_adapter #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) adapter (
        .mem_valid  (mem_valid),
        .mem_instr  (mem_instr),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),

        .mem_ready  (mem_ready),
        .mem_rdata  (mem_rdata),

        .m_valid    (m_valid),
        .m_write    (m_write),
        .m_addr     (m_addr),
        .m_wdata    (m_wdata),
        .m_strb     (m_strb),

        .m_ready    (m_ready),
        .m_rdata    (m_rdata)
    );


    // =========================================================================
    // SoC Memory Interconnect
    //
    // NOTE:
    // No clk/reset here.
    //
    // The interconnect is purely combinational address decoding/routing.
    // =========================================================================

    soc_mem_interconnect #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) \interconnect (

        // Master
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

        .gpio_ready  (gpio_ready),
        .gpio_rdata  (gpio_rdata),

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
        .vdp_strb    (vdp_strb),

        .vdp_ready  (vdp_ready),
        .vdp_rdata  (vdp_rdata)
    );


    // =========================================================================
    // RAM
    //
    // soc_ram reset is active-high.
    //
    // Top-level reset is active-low.
    //
    // Therefore:
    //
    //     reset = ~resetn
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
    // GPIO
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
    // SENSOR STATUS
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
    // RF TELEMETRY
    // =========================================================================

    rf_telemetry_native_slave #(
        .ADDR_WIDTH (12),
        .DATA_WIDTH (DATA_WIDTH)
    ) rf (

        .clk             (clk),
        .resetn          (resetn),

        .mem_valid       (rf_valid),
        .mem_instr       (1'b0),
        .mem_ready       (rf_ready),

        .mem_addr        (rf_addr),
        .mem_wdata       (rf_wdata),
        .mem_wstrb       (rf_strb),
        .mem_rdata       (rf_rdata),

        .rssi_dbm_i      (rssi_dbm_i),
        .link_up_i       (link_up_i),
        .link_error_i    (link_error_i),
        .carrier_detect_i(carrier_detect_i),

        .rf_enable_o     (rf_enable_o)
    );


    // =========================================================================
    // VDP / VGA
    // =========================================================================

    vdp_native_slave vdp (

        // System/native bus clock
        .clk        (clk),
        .resetn     (resetn),

        .mem_valid  (vdp_valid),
        .mem_instr  (1'b0),
        .mem_ready  (vdp_ready),

        .mem_addr   (vdp_addr),
        .mem_wdata  (vdp_wdata),
        .mem_wstrb  (vdp_strb),
        .mem_rdata  (vdp_rdata),

        // Independent VGA pixel clock
        .pixel_clk  (pixel_clk),

        // VGA timing
        .hsync_o    (hsync_o),
        .vsync_o    (vsync_o),

        .pixel_x_o  (pixel_x_o),
        .pixel_y_o  (pixel_y_o),

        // RGB444
        .rgb_r_o    (rgb_r_o),
        .rgb_g_o    (rgb_g_o),
        .rgb_b_o    (rgb_b_o)
    );


endmodule
`endif