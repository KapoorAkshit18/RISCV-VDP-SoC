module soc_mem_interconnect_formal (
    input clk,
    input resetn,
    input         m_valid,
    input         m_write,
    input  [31:0] m_addr,
    input  [31:0] m_wdata,
    input  [ 3:0] m_strb,
    input         m_ready,
    input  [31:0] m_rdata,
    
    input         ram_valid,
    input         ram_write,
    input  [31:0] ram_addr,
    input  [31:0] ram_wdata,
    input  [ 3:0] ram_strb,
    input         ram_ready,
    input  [31:0] ram_rdata,

    input         gpio_valid,
    input         rf_valid,
    input         sensor_valid,
    input         vdp_valid,
    input         nn_valid
);

    wire is_ram      = (m_addr & 32'hFFFF_0000) == 32'h0000_0000;
    wire is_gpio     = (m_addr & 32'hFFFF_F000) == 32'h0001_0000;
    wire is_rf       = (m_addr & 32'hFFFF_F000) == 32'h0001_1000;
    wire is_sensor   = (m_addr & 32'hFFFF_F000) == 32'h0001_2000;
    wire is_vdp      = (m_addr & 32'hFFFF_F000) == 32'h0001_3000;
    wire is_nn       = (m_addr & 32'hFFFF_F000) == 32'h0001_4000;
    wire is_unmapped = !(is_ram || is_gpio || is_rf || is_sensor || is_vdp || is_nn);

    always @(*) begin
        // Cover properties
        cover(m_valid && is_ram);
        cover(m_valid && is_sensor);

        // IC_A01: Target Selection
        if (m_valid && is_ram) begin
            assert(ram_valid == 1'b1);
            assert(ram_addr == m_addr);
        end

        // IC_A02: Target Isolation
        if (m_valid) begin
            assert((ram_valid + gpio_valid + rf_valid + sensor_valid + vdp_valid + nn_valid) <= 1);
        end

        // IC_A03: Unmapped
        if (m_valid && is_unmapped) begin
            assert(m_ready == 1'b1);
            assert(m_rdata == 32'b0);
        end
    end
endmodule

bind soc_mem_interconnect soc_mem_interconnect_formal u_checker (
    .clk(1'b0),
    .resetn(1'b1),
    .m_valid(m_valid),
    .m_write(m_write),
    .m_addr(m_addr),
    .m_wdata(m_wdata),
    .m_strb(m_strb),
    .m_ready(m_ready),
    .m_rdata(m_rdata),
    
    .ram_valid(ram_valid),
    .ram_write(ram_write),
    .ram_addr(ram_addr),
    .ram_wdata(ram_wdata),
    .ram_strb(ram_strb),
    .ram_ready(ram_ready),
    .ram_rdata(ram_rdata),
    
    .gpio_valid(gpio_valid),
    .rf_valid(rf_valid),
    .sensor_valid(sensor_valid),
    .vdp_valid(vdp_valid),
    .nn_valid(nn_valid)
);

