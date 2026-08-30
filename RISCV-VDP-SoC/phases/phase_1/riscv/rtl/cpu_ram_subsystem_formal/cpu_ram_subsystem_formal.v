`ifndef CPU_RAM_SUBSYSTEM_FORMAL_V
`define CPU_RAM_SUBSYSTEM_FORMAL_V

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
        resetn = 1'b0;
    end

    always #5 clk = ~clk;

    /*
     * --------------------------------------------------------
     * Reset assumption
     * --------------------------------------------------------
     */

    always @(posedge clk) begin
        if (!resetn) begin
            assert(dut.ram_valid == 1'b0 ||
                   dut.u_ram.reset == 1'b1);
        end
    end

    /*
     * --------------------------------------------------------
     * Adapter mapping
     * --------------------------------------------------------
     */

    always @(*) begin

        assert(dut.m_valid == dut.mem_valid);

        assert(dut.m_write == (|dut.mem_wstrb));

        assert(dut.m_addr == dut.mem_addr);

        assert(dut.m_wdata == dut.mem_wdata);

        assert(dut.m_strb == dut.mem_wstrb);

        assert(dut.mem_ready == dut.m_ready);

        assert(dut.mem_rdata == dut.m_rdata);

    end

    /*
     * --------------------------------------------------------
     * RAM request cannot exist without an interconnect request
     * --------------------------------------------------------
     */

    always @(*) begin
        if (dut.ram_valid)
            assert(dut.m_valid);
    end

    /*
     * --------------------------------------------------------
     * GPIO placeholder must never acknowledge
     * --------------------------------------------------------
     */

    always @(*) begin
        assert(dut.gpio_ready == 1'b0);
        assert(dut.gpio_rdata == 32'b0);
    end

endmodule

`endif