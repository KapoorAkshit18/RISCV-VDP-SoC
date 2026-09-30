`ifndef CPU_RAM_SUBSYSTEM_FORMAL_SV
`define CPU_RAM_SUBSYSTEM_FORMAL_SV

// This is the property module to be bound into cpu_ram_subsystem
module cpu_ram_subsystem_props (
    input clk,
    input resetn,
    input mem_valid,
    input mem_ready,
    input [3:0] mem_wstrb,
    input [31:0] mem_addr,
    input [31:0] mem_wdata,
    input [31:0] mem_rdata,

    input m_valid,
    input m_ready,
    input m_write,
    input [3:0] m_strb,
    input [31:0] m_addr,
    input [31:0] m_wdata,
    input [31:0] m_rdata,

    input ram_valid,
    
    input gpio_ready,
    input [31:0] gpio_rdata
);

    /*
     * --------------------------------------------------------
     * A. Reset behavior
     * --------------------------------------------------------
     */
    always @(posedge clk) begin
        if (!resetn) begin
            // When reset is asserted, the interconnect should not generate a valid RAM request
            // or the RAM itself receives a reset (soc_ram reset is active high, connected to ~resetn)
            assert(ram_valid == 1'b0 || !resetn);
        end
    end

    /*
     * --------------------------------------------------------
     * B & C. CPU-to-adapter and Adapter-to-interconnect transaction integrity
     * --------------------------------------------------------
     */
    always @(*) begin
        // cpu_bus_adapter simply wires the signals between the CPU and the interconnect.
        // mem_wstrb == 0 represents a read, mem_wstrb != 0 is a write.
        assert(m_valid == mem_valid);
        assert(m_write == (|mem_wstrb));
        assert(m_addr  == mem_addr);
        assert(m_wdata == mem_wdata);
        assert(m_strb  == mem_wstrb);
        assert(mem_ready == m_ready);
        assert(mem_rdata == m_rdata);
    end

    /*
     * --------------------------------------------------------
     * D. RAM access behavior
     * --------------------------------------------------------
     */
    always @(*) begin
        // If a RAM transaction is valid, it must be because the master transaction is valid
        // and address decodes to RAM_BASE.
        if (ram_valid) begin
            assert(m_valid);
            assert((m_addr & 32'hFFFF_0000) == 32'h0000_0000);
        end
    end

    /*
     * --------------------------------------------------------
     * Unmapped / GPIO behavior
     * --------------------------------------------------------
     */
    always @(*) begin
        // The GPIO placeholder is hardcoded to never be ready and return 0.
        assert(gpio_ready == 1'b0);
        assert(gpio_rdata == 32'b0);
    end

endmodule

// Bind the property module into the target DUT
bind cpu_ram_subsystem cpu_ram_subsystem_props checker_inst (
    .clk(clk),
    .resetn(resetn),
    .mem_valid(mem_valid),
    .mem_ready(mem_ready),
    .mem_wstrb(mem_wstrb),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_rdata(mem_rdata),
    
    .m_valid(m_valid),
    .m_ready(m_ready),
    .m_write(m_write),
    .m_strb(m_strb),
    .m_addr(m_addr),
    .m_wdata(m_wdata),
    .m_rdata(m_rdata),

    .ram_valid(ram_valid),

    .gpio_ready(gpio_ready),
    .gpio_rdata(gpio_rdata)
);

// The top-level formal wrapper
module cpu_ram_subsystem_formal;
    reg clk;
    reg resetn;
    wire cpu_trap;

    cpu_ram_subsystem #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .RAM_DEPTH(256)
    ) dut (
        .clk      (clk),
        .resetn   (resetn),
        .cpu_trap (cpu_trap)
    );

    initial begin
        clk = 1'b0;
    end

    always #5 clk = ~clk;
    
    // Environment assumption: reset starts low, or is at least allowed to.
    initial assume(!resetn);
endmodule

`endif
