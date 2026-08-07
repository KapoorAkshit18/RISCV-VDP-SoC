`ifndef CPU_BUS_ADAPTER_FORMAL_V
`define CPU_BUS_ADAPTER_FORMAL_V

module cpu_bus_adapter_formal;

    reg         mem_valid;
    reg         mem_instr;
    reg  [31:0] mem_addr;
    reg  [31:0] mem_wdata;
    reg  [3:0]  mem_wstrb;

    reg         m_ready;
    reg  [31:0] m_rdata;

    wire        mem_ready;
    wire [31:0] mem_rdata;

    wire        m_valid;
    wire        m_write;
    wire [31:0] m_addr;
    wire [31:0] m_wdata;
    wire [3:0]  m_strb;

    cpu_bus_adapter dut (
        .mem_valid (mem_valid),
        .mem_instr (mem_instr),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),

        .mem_ready (mem_ready),
        .mem_rdata (mem_rdata),

        .m_valid   (m_valid),
        .m_write   (m_write),
        .m_addr    (m_addr),
        .m_wdata   (m_wdata),
        .m_strb    (m_strb),

        .m_ready   (m_ready),
        .m_rdata   (m_rdata)
    );

    // ----------------------------------------------------
    // Formal mapping properties
    // ----------------------------------------------------

    always @(*) begin

        assert(m_valid == mem_valid);

        assert(m_write == (|mem_wstrb));

        assert(m_addr == mem_addr);

        assert(m_wdata == mem_wdata);

        assert(m_strb == mem_wstrb);

        assert(mem_ready == m_ready);

        assert(mem_rdata == m_rdata);

    end

endmodule

`endif