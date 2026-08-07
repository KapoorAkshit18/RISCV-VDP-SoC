`ifndef CPU_BUS_ADAPTER_V
`define CPU_BUS_ADAPTER_V

module cpu_bus_adapter #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    // PicoRV32 memory interface
    input  wire                     mem_valid,
    input  wire                     mem_instr,
    input  wire [ADDR_WIDTH-1:0]    mem_addr,
    input  wire [DATA_WIDTH-1:0]    mem_wdata,
    input  wire [DATA_WIDTH/8-1:0]  mem_wstrb,

    output wire                     mem_ready,
    output wire [DATA_WIDTH-1:0]    mem_rdata,

    // SoC interconnect master interface
    output wire                     m_valid,
    output wire                     m_write,
    output wire [ADDR_WIDTH-1:0]    m_addr,
    output wire [DATA_WIDTH-1:0]    m_wdata,
    output wire [DATA_WIDTH/8-1:0]  m_strb,

     input  wire                     m_ready,
     input  wire [DATA_WIDTH-1:0]    m_rdata
);

    // ------------------------------------------------
    // Request mapping
    // ------------------------------------------------

    assign m_valid = mem_valid;

    // PicoRV32 uses mem_wstrb != 0 for writes.
    // mem_wstrb == 0 represents a read/instruction fetch.
    assign m_write = |mem_wstrb;

    assign m_addr  = mem_addr;
    assign m_wdata = mem_wdata;
    assign m_strb  = mem_wstrb;

    // ------------------------------------------------
    // Response mapping
    // ------------------------------------------------

    assign mem_ready = m_ready;
    assign mem_rdata = m_rdata;

endmodule

`endif