`ifndef CPU_RAM_SUBSYSTEM_V
`define CPU_RAM_SUBSYSTEM_V

module cpu_ram_subsystem #(
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
    // GPIO placeholder
    // ============================================================

    wire                     gpio_valid;
    wire                     gpio_write;
    wire [ADDR_WIDTH-1:0]    gpio_addr;
    wire [DATA_WIDTH-1:0]    gpio_wdata;
    wire [DATA_WIDTH/8-1:0]  gpio_strb;

    wire                     gpio_ready;
    wire [DATA_WIDTH-1:0]    gpio_rdata;

    assign gpio_ready = 1'b0;
    assign gpio_rdata = {DATA_WIDTH{1'b0}};

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
        .m_valid    (m_valid),
        .m_write    (m_write),
        .m_addr     (m_addr),
        .m_wdata    (m_wdata),
        .m_strb     (m_strb),

        .m_ready    (m_ready),
        .m_rdata    (m_rdata),

        .ram_valid  (ram_valid),
        .ram_write  (ram_write),
        .ram_addr   (ram_addr),
        .ram_wdata  (ram_wdata),
        .ram_strb   (ram_strb),

        .ram_ready  (ram_ready),
        .ram_rdata  (ram_rdata),

        .gpio_valid (gpio_valid),
        .gpio_write (gpio_write),
        .gpio_addr  (gpio_addr),
        .gpio_wdata (gpio_wdata),
        .gpio_strb  (gpio_strb),

        .gpio_ready (gpio_ready),
        .gpio_rdata (gpio_rdata)
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