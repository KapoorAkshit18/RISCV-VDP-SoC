`ifndef CPU_SOC_RAM_TOP_V
`define CPU_SOC_RAM_TOP_V

module cpu_soc_ram_top #(
    parameter ADDR_WIDTH     = 32,
    parameter DATA_WIDTH     = 32,
    parameter RAM_ADDR_WIDTH = 16,
    parameter RAM_DEPTH      = 256
)(
    input  wire clk,
    input  wire resetn,

    // External sensor inputs
    input  wire [7:0]  battery_percent_i,
    input  wire [15:0] battery_voltage_mv_i,
    input  wire [15:0] temperature_tenthsC_i,
    input  wire        sensor_valid_i,

    output wire trap
);

    // ================================================================
    // PicoRV32 native memory interface
    // ================================================================

    wire                     mem_valid;
    wire                     mem_instr;
    wire [ADDR_WIDTH-1:0]    mem_addr;
    wire [DATA_WIDTH-1:0]    mem_wdata;
    wire [DATA_WIDTH/8-1:0]  mem_wstrb;

    wire                     mem_ready;
    wire [DATA_WIDTH-1:0]    mem_rdata;


    // ================================================================
    // CPU bus adapter
    // ================================================================

    wire                     m_valid;
    wire                     m_write;
    wire [ADDR_WIDTH-1:0]    m_addr;
    wire [DATA_WIDTH-1:0]    m_wdata;
    wire [DATA_WIDTH/8-1:0]  m_strb;

    wire                     m_ready;
    wire [DATA_WIDTH-1:0]    m_rdata;


    // ================================================================
    // RAM
    // ================================================================

    wire                     ram_valid;
    wire                     ram_write;
    wire [ADDR_WIDTH-1:0]    ram_addr;
    wire [DATA_WIDTH-1:0]    ram_wdata;
    wire [DATA_WIDTH/8-1:0]  ram_strb;

    wire                     ram_ready;
    wire [DATA_WIDTH-1:0]    ram_rdata;


    // ================================================================
    // GPIO
    // ================================================================

    wire                     gpio_valid;
    wire                     gpio_write;
    wire [ADDR_WIDTH-1:0]    gpio_addr;
    wire [DATA_WIDTH-1:0]    gpio_wdata;
    wire [DATA_WIDTH/8-1:0]  gpio_strb;

    wire                     gpio_ready;
    wire [DATA_WIDTH-1:0]    gpio_rdata;

    assign gpio_ready = 1'b0;
    assign gpio_rdata = 32'h0000_0000;


    // ================================================================
    // SENSOR
    // ================================================================

    wire                     sensor_valid;
    wire                     sensor_write;
    wire [ADDR_WIDTH-1:0]    sensor_addr;
    wire [DATA_WIDTH-1:0]    sensor_wdata;
    wire [DATA_WIDTH/8-1:0]  sensor_strb;

    wire                     sensor_ready;
    wire [DATA_WIDTH-1:0]    sensor_rdata;


    // ================================================================
    // RF
    // ================================================================

    wire                     rf_valid;
    wire                     rf_write;
    wire [ADDR_WIDTH-1:0]    rf_addr;
    wire [DATA_WIDTH-1:0]    rf_wdata;
    wire [DATA_WIDTH/8-1:0]  rf_strb;

    wire                     rf_ready;
    wire [DATA_WIDTH-1:0]    rf_rdata;


    // ================================================================
    // VDP
    // ================================================================

    wire                     vdp_valid;
    wire                     vdp_write;
    wire [ADDR_WIDTH-1:0]    vdp_addr;
    wire [DATA_WIDTH-1:0]    vdp_wdata;
    wire [DATA_WIDTH/8-1:0]  vdp_strb;

    wire                     vdp_ready;
    wire [DATA_WIDTH-1:0]    vdp_rdata;


    // ================================================================
    // PicoRV32
    // ================================================================

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


    // ================================================================
    // CPU -> native bus adapter
    // ================================================================

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


    // ================================================================
    // SoC memory interconnect
    // ================================================================

    soc_mem_interconnect #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) interconnect (
        .clk        (clk),
        .resetn     (resetn),

        .m_valid    (m_valid),
        .m_write    (m_write),
        .m_addr     (m_addr),
        .m_wdata    (m_wdata),
        .m_strb     (m_strb),

        .m_ready    (m_ready),
        .m_rdata    (m_rdata),

        // RAM
        .ram_valid  (ram_valid),
        .ram_write  (ram_write),
        .ram_addr   (ram_addr),
        .ram_wdata  (ram_wdata),
        .ram_strb   (ram_strb),
        .ram_ready  (ram_ready),
        .ram_rdata  (ram_rdata),

        // GPIO
        .gpio_valid (gpio_valid),
        .gpio_write (gpio_write),
        .gpio_addr  (gpio_addr),
        .gpio_wdata (gpio_wdata),
        .gpio_strb  (gpio_strb),
        .gpio_ready (gpio_ready),
        .gpio_rdata (gpio_rdata),

        // Sensor
        .sensor_valid (sensor_valid),
        .sensor_write (sensor_write),
        .sensor_addr  (sensor_addr),
        .sensor_wdata (sensor_wdata),
        .sensor_strb  (sensor_strb),
        .sensor_ready (sensor_ready),
        .sensor_rdata (sensor_rdata),

        // RF
        .rf_valid (rf_valid),
        .rf_write (rf_write),
        .rf_addr  (rf_addr),
        .rf_wdata (rf_wdata),
        .rf_strb  (rf_strb),
        .rf_ready (rf_ready),
        .rf_rdata (rf_rdata),

        // VDP
        .vdp_valid (vdp_valid),
        .vdp_write (vdp_write),
        .vdp_addr  (vdp_addr),
        .vdp_wdata (vdp_wdata),
        .vdp_strb  (vdp_strb),
        .vdp_ready (vdp_ready),
        .vdp_rdata (vdp_rdata)
    );


    // ================================================================
    // RAM
    // ================================================================

    soc_ram #(
        .ADDR_WIDTH (RAM_ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (RAM_DEPTH)
    ) ram (
        .valid  (ram_valid),
        .write  (ram_write),
        .addr   (ram_addr[RAM_ADDR_WIDTH-1:0]),
        .wdata  (ram_wdata),
        .strb   (ram_strb),
        .ready  (ram_ready),
        .rdata  (ram_rdata)
    );


    // ================================================================
    // SENSOR STATUS
    // ================================================================

    sensor_status_native_slave sensor (
        .clk                    (clk),
        .resetn                 (resetn),

        .mem_valid              (sensor_valid),
        .mem_instr              (1'b0),
        .mem_ready              (sensor_ready),
        .mem_addr               (sensor_addr[11:0]),
        .mem_wdata              (sensor_wdata),
        .mem_wstrb              (sensor_strb),
        .mem_rdata              (sensor_rdata),

        .battery_percent_i      (battery_percent_i),
        .battery_voltage_mv_i   (battery_voltage_mv_i),
        .temperature_tenthsC_i  (temperature_tenthsC_i),
        .sensor_valid_i         (sensor_valid_i)
    );


    // ================================================================
    // RF
    // ================================================================

    // Connect your already-verified rf_telemetry_native_slave here.
    //
    // For now, these are tied inactive until the RF external inputs
    // are exposed at this top level.

    assign rf_ready = 1'b0;
    assign rf_rdata = 32'h0000_0000;


    // ================================================================
    // VDP
    // ================================================================

    // Connect the already-tested VDP native slave here.
    //
    // VDP has an independent pixel clock in your current implementation,
    // so we should integrate it only after its CDC interface is frozen.

    assign vdp_ready = 1'b0;
    assign vdp_rdata = 32'h0000_0000;

endmodule

`endif