module soc_mem_interconnect #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    // Master side
    input  wire                     m_valid,
    input  wire                     m_write,
    input  wire [ADDR_WIDTH-1:0]    m_addr,
    input  wire [DATA_WIDTH-1:0]    m_wdata,
    input  wire [DATA_WIDTH/8-1:0]  m_strb,

    output reg                      m_ready,
    output reg  [DATA_WIDTH-1:0]    m_rdata,

    // RAM slave
    output reg                      ram_valid,
    output reg                      ram_write,
    output reg  [ADDR_WIDTH-1:0]    ram_addr,
    output reg  [DATA_WIDTH-1:0]    ram_wdata,
    output reg  [DATA_WIDTH/8-1:0]  ram_strb,

    input  wire                     ram_ready,
    input  wire [DATA_WIDTH-1:0]     ram_rdata,

    // GPIO slave
    output reg                      gpio_valid,
    output reg                      gpio_write,
    output reg  [ADDR_WIDTH-1:0]    gpio_addr,
    output reg  [DATA_WIDTH-1:0]    gpio_wdata,
    output reg  [DATA_WIDTH/8-1:0]  gpio_strb,

    input  wire                     gpio_ready,
    input  wire [DATA_WIDTH-1:0]     gpio_rdata
);

    // Address map
    localparam RAM_BASE  = 32'h0000_0000;
    localparam RAM_MASK  = 32'hFFFF_0000;

    localparam GPIO_BASE = 32'h4000_0000;
    localparam GPIO_MASK = 32'hFFFF_F000;

    wire ram_sel;
    wire gpio_sel;

    assign ram_sel  = ((m_addr & RAM_MASK)  == RAM_BASE);
    assign gpio_sel = ((m_addr & GPIO_MASK) == GPIO_BASE);

    always @(*) begin

        // Defaults
        m_ready = 1'b0;
        m_rdata = {DATA_WIDTH{1'b0}};

        ram_valid = 1'b0;
        ram_write  = 1'b0;
        ram_addr   = {ADDR_WIDTH{1'b0}};
        ram_wdata  = {DATA_WIDTH{1'b0}};
        ram_strb   = {(DATA_WIDTH/8){1'b0}};

        gpio_valid = 1'b0;
        gpio_write  = 1'b0;
        gpio_addr   = {ADDR_WIDTH{1'b0}};
        gpio_wdata  = {DATA_WIDTH{1'b0}};
        gpio_strb   = {(DATA_WIDTH/8){1'b0}};

        // -------------------------
        // Address decoding
        // -------------------------

        if (m_valid && ram_sel) begin

            ram_valid = 1'b1;
            ram_write = m_write;
            ram_addr  = m_addr;
            ram_wdata = m_wdata;
            ram_strb  = m_strb;

            m_ready = ram_ready;
            m_rdata = ram_rdata;

        end

        else if (m_valid && gpio_sel) begin

            gpio_valid = 1'b1;
            gpio_write = m_write;
            gpio_addr  = m_addr;
            gpio_wdata = m_wdata;
            gpio_strb  = m_strb;

            m_ready = gpio_ready;
            m_rdata = gpio_rdata;

        end
    end

endmodule