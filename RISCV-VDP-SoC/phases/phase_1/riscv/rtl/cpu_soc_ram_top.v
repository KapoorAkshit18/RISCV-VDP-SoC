`ifndef CPU_SOC_RAM_TOP
`define CPU_SOC_RAM_TOP

module cpu_soc_ram_top #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter RAM_DEPTH  = 256
)(
    input  wire clk,
    input  wire resetn,

    output wire cpu_trap
);

    // ============================================================
    // PicoRV32 / PTB memory interface
    // ============================================================

    wire                     mem_valid;
    wire                     mem_instr;
    wire                     mem_ready;
    wire [ADDR_WIDTH-1:0]    mem_addr;
    wire [DATA_WIDTH-1:0]    mem_wdata;
    wire [DATA_WIDTH/8-1:0]  mem_wstrb;
    wire [DATA_WIDTH-1:0]    mem_rdata;

    // ============================================================
    // CPU adapter -> interconnect
    // ============================================================

    wire                     m_valid;
    wire                     m_write;
    wire [ADDR_WIDTH-1:0]    m_addr;
    wire [DATA_WIDTH-1:0]    m_wdata;
    wire [DATA_WIDTH/8-1:0]  m_strb;

    wire                     m_ready;
    wire [DATA_WIDTH-1:0]    m_rdata;

    // ============================================================
    // RAM interface
    // ============================================================

    wire                     ram_valid;
    wire                     ram_write;
    wire [ADDR_WIDTH-1:0]    ram_addr;
    wire [DATA_WIDTH-1:0]    ram_wdata;
    wire [DATA_WIDTH/8-1:0]  ram_strb;

    wire                     ram_ready;
    wire [DATA_WIDTH-1:0]    ram_rdata;

    // ============================================================
    // GPIO interface
    // ============================================================

    wire                     gpio_valid;
    wire                     gpio_write;
    wire [11:0]              gpio_addr;
    wire [DATA_WIDTH-1:0]    gpio_wdata;
    wire [DATA_WIDTH/8-1:0]  gpio_strb;

    wire                     gpio_ready;
    wire [DATA_WIDTH-1:0]    gpio_rdata;

    assign gpio_ready = 1'b0;
    assign gpio_rdata = {DATA_WIDTH{1'b0}};

    // ============================================================
    // RF interface
    // ============================================================

    wire                     rf_valid;
    wire                     rf_write;
    wire [11:0]              rf_addr;
    wire [DATA_WIDTH-1:0]    rf_wdata;
    wire [DATA_WIDTH/8-1:0]  rf_strb;

    wire                     rf_ready;
    wire [DATA_WIDTH-1:0]    rf_rdata;

    // Placeholder until RF slave is connected
    assign rf_ready = 1'b0;
    assign rf_rdata = {DATA_WIDTH{1'b0}};

    // ============================================================
    // Sensor interface
    // ============================================================

    wire                     sensor_valid;
    wire                     sensor_write;
    wire [11:0]              sensor_addr;
    wire [DATA_WIDTH-1:0]    sensor_wdata;
    wire [DATA_WIDTH/8-1:0]  sensor_strb;

    wire                     sensor_ready;
    wire [DATA_WIDTH-1:0]    sensor_rdata;

    // Placeholder until Sensor slave is connected
    assign sensor_ready = 1'b0;
    assign sensor_rdata = {DATA_WIDTH{1'b0}};

    // ============================================================
    // VDP interface
    // ============================================================

    wire                     vdp_valid;
    wire                     vdp_write;
    wire [11:0]              vdp_addr;
    wire [DATA_WIDTH-1:0]    vdp_wdata;
    wire [DATA_WIDTH/8-1:0]  vdp_strb;

    wire                     vdp_ready;
    wire [DATA_WIDTH-1:0]    vdp_rdata;

    // Placeholder until VDP slave is connected
    assign vdp_ready = 1'b0;
    assign vdp_rdata = {DATA_WIDTH{1'b0}};

    // ============================================================
    // Verified PicoRV32 wrapper
    // ============================================================

    ptb u_cpu (
        .clk        (clk),
        .resetn     (resetn),

        .mem_ready  (mem_ready),
        .mem_rdata  (mem_rdata),

        .trap       (cpu_trap),

        .mem_valid  (mem_valid),
        .mem_instr  (mem_instr),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb)
    );

    // ============================================================
    // CPU Bus Adapter
    // ============================================================

    cpu_bus_adapter #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_adapter (
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

    // ============================================================
    // SoC Memory Interconnect
    // ============================================================

    soc_mem_interconnect #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_interconnect (
        // --------------------------------------------------------
        // Master
        // --------------------------------------------------------
        .m_valid    (m_valid),
        .m_write    (m_write),
        .m_addr     (m_addr),
        .m_wdata    (m_wdata),
        .m_strb     (m_strb),

        .m_ready    (m_ready),
        .m_rdata    (m_rdata),

        // --------------------------------------------------------
        // RAM
        // --------------------------------------------------------
        .ram_valid  (ram_valid),
        .ram_write  (ram_write),
        .ram_addr   (ram_addr),
        .ram_wdata  (ram_wdata),
        .ram_strb   (ram_strb),

        .ram_ready  (ram_ready),
        .ram_rdata  (ram_rdata),

        // --------------------------------------------------------
        // GPIO
        // --------------------------------------------------------
        .gpio_valid (gpio_valid),
        .gpio_write (gpio_write),
        .gpio_addr  (gpio_addr),
        .gpio_wdata (gpio_wdata),
        .gpio_strb  (gpio_strb),

        .gpio_ready  (gpio_ready),
        .gpio_rdata  (gpio_rdata),

        // --------------------------------------------------------
        // RF
        // --------------------------------------------------------
        .rf_valid   (rf_valid),
        .rf_write   (rf_write),
        .rf_addr    (rf_addr),
        .rf_wdata   (rf_wdata),
        .rf_strb    (rf_strb),

        .rf_ready   (rf_ready),
        .rf_rdata   (rf_rdata),

        // --------------------------------------------------------
        // Sensor
        // --------------------------------------------------------
        .sensor_valid (sensor_valid),
        .sensor_write (sensor_write),
        .sensor_addr  (sensor_addr),
        .sensor_wdata (sensor_wdata),
        .sensor_strb  (sensor_strb),

        .sensor_ready  (sensor_ready),
        .sensor_rdata  (sensor_rdata),

        // --------------------------------------------------------
        // VDP
        // --------------------------------------------------------
        .vdp_valid  (vdp_valid),
        .vdp_write  (vdp_write),
        .vdp_addr   (vdp_addr),
        .vdp_wdata  (vdp_wdata),
        .vdp_strb   (vdp_strb),

        .vdp_ready  (vdp_ready),
        .vdp_rdata  (vdp_rdata)
    );

    // ============================================================
    // RAM
    // ============================================================

    soc_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH     (RAM_DEPTH)
    ) u_ram (
        .clk   (clk),
        .reset (~resetn),
        .valid (ram_valid),
        .write (ram_write),
        .addr  (ram_addr),
        .wdata (ram_wdata),
        .strb  (ram_strb),
        .ready (ram_ready),
        .rdata (ram_rdata)
    );

endmodule

`endif
