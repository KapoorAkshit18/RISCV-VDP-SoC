module cpu_bus_formal (
    input clk,
    input resetn,

    // Abstract master signals
    input         mem_valid,
    input         mem_instr,
    input  [31:0] mem_addr,
    input  [31:0] mem_wdata,
    input  [ 3:0] mem_wstrb,
    input         mem_ready,
    input  [31:0] mem_rdata,

    // Adapter master signals
    input         m_valid,
    input         m_write,
    input  [31:0] m_addr,
    input  [31:0] m_wdata,
    input  [ 3:0] m_strb,
    input         m_ready,
    input  [31:0] m_rdata,

    // Interconnect to RAM signals
    input         ram_valid,
    input         ram_write,
    input  [31:0] ram_addr,
    input  [31:0] ram_wdata,
    input  [ 3:0] ram_strb,
    input         ram_ready,
    input  [31:0] ram_rdata
);

    // Track initialization
    reg past_valid;
    initial past_valid = 1'b0;
    always @(posedge clk) past_valid <= 1'b1;

    // A. Handshake Contract Stability (Assertion on Master)
    // Transaction information MUST remain stable during a wait state
    always @(posedge clk) begin
        if (past_valid && $past(resetn)) begin
            if ($past(mem_valid) && !$past(mem_ready)) begin
                assert(mem_valid == 1'b1);
                assert(mem_addr  == $past(mem_addr));
                assert(mem_wdata == $past(mem_wdata));
                assert(mem_wstrb == $past(mem_wstrb));
                assert(mem_instr == $past(mem_instr));
            end
        end
    end

    // B. Adapter Integrity
    // Validates that the bus adapter strictly follows combinatorial propagation
    always @(*) begin
        if (resetn) begin
            assert(m_valid == mem_valid);
            assert(m_write == (|mem_wstrb)); // write active if any strobe bit is 1
            assert(m_addr  == mem_addr);
            assert(m_wdata == mem_wdata);
            assert(m_strb  == mem_wstrb);
            assert(mem_ready == m_ready);
            assert(mem_rdata == m_rdata);
        end
    end

    // Address Decoding Map from Phase 7 RTL
    wire is_ram    = (m_addr & 32'hFFFF_0000) == 32'h0000_0000;
    wire is_gpio   = (m_addr & 32'hFFFF_F000) == 32'h0001_0000;
    wire is_rf     = (m_addr & 32'hFFFF_F000) == 32'h0001_1000;
    wire is_sensor = (m_addr & 32'hFFFF_F000) == 32'h0001_2000;
    wire is_vdp    = (m_addr & 32'hFFFF_F000) == 32'h0001_3000;
    wire is_nn     = (m_addr & 32'hFFFF_F000) == 32'h0001_4000;

    always @(*) begin
        if (resetn) begin
            if (m_valid && is_ram) begin
                // Selected target is correctly routed
                assert(ram_valid == 1'b1);
                assert(m_ready == ram_ready);
                assert(m_rdata == ram_rdata);
                
                assert(ram_addr == m_addr);
                assert(ram_wdata == m_wdata);
                assert(ram_strb == m_strb);
            end else begin
                // Non-selected target is kept quiet
                assert(ram_valid == 1'b0);
            end
        end
    end

    // D. Unmapped Address Behavior
    always @(*) begin
        if (resetn) begin
            if (m_valid && !is_ram && !is_gpio && !is_rf && !is_sensor && !is_vdp && !is_nn) begin
                // Interconnect safely returns ready=1 and rdata=0 for unmapped to prevent CPU hang
                assert(m_ready == 1'b1);
                assert(m_rdata == 32'b0);
            end
        end
    end

    // E. RAM Latency/Handshake (Liveness/Contract)
    // The soc_ram takes exactly 1 clock cycle to process and raise ready
    always @(posedge clk) begin
        if (past_valid && $past(resetn)) begin
            if ($past(ram_valid)) begin
                // If it was valid last cycle, ready MUST be 1 this cycle
                assert(ram_ready == 1'b1);
            end
        end
    end

endmodule
