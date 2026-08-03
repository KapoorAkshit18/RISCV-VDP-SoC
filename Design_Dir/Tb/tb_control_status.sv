`timescale 1ns/1ps
// =============================================================================
// tb_control_status.v -- self-checking testbench for control_status_axi_slave
// Run with: iverilog -o sim_ctrl tb_control_status.v ../rtl/control_status_axi_slave.v && vvp sim_ctrl
// =============================================================================
module tb_control_status;

    reg clk = 0;
    reg rst_n;

    reg  [11:0] awaddr; reg awvalid; wire awready;
    reg  [31:0] wdata;  reg [3:0] wstrb; reg wvalid; wire wready;
    wire [1:0]  bresp;  wire bvalid; reg bready;
    reg  [11:0] araddr; reg arvalid; wire arready;
    wire [31:0] rdata;  wire [1:0] rresp; wire rvalid; reg rready;

    reg gpio_irq, sensor_alarm, rf_link_up, vdp_frame_flag;
    wire soft_reset;

    integer errors = 0;

    control_status_axi_slave dut (
        .s_axi_aclk(clk), .s_axi_aresetn(rst_n),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .gpio_irq_i(gpio_irq), .sensor_alarm_i(sensor_alarm),
        .rf_link_up_i(rf_link_up), .vdp_frame_flag_i(vdp_frame_flag),
        .soft_reset_o(soft_reset)
    );

    always #5 clk = ~clk;

    task axi_write(input [11:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            awaddr <= addr; awvalid <= 1'b1; wdata <= data; wstrb <= 4'hF; wvalid <= 1'b1; bready <= 1'b1;
            @(posedge clk);
            while (!(awready && wready)) @(posedge clk);
            awvalid <= 1'b0; wvalid <= 1'b0;
            while (!bvalid) @(posedge clk);
            @(posedge clk);
        end
    endtask

    task axi_read(input [11:0] addr, output [31:0] data, output [1:0] resp);
        begin
            @(posedge clk);
            araddr <= addr; arvalid <= 1'b1; rready <= 1'b1;
            @(posedge clk);
            while (!arready) @(posedge clk);
            arvalid <= 1'b0;
            while (!rvalid) @(posedge clk);
            data = rdata; resp = rresp;
            @(posedge clk);
        end
    endtask

    reg [31:0] rd_data; reg [1:0] rd_resp;

    initial begin
        rst_n = 0; awvalid=0; wvalid=0; bready=0; arvalid=0; rready=0;
        awaddr=0; wdata=0; wstrb=0; araddr=0;
        gpio_irq=1'b0; sensor_alarm=1'b0; rf_link_up=1'b1; vdp_frame_flag=1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        axi_read(12'h000, rd_data, rd_resp);
        if (rd_data === 32'h5644_5030) $display("PASS: SOC_ID = %h (\"VDP0\")", rd_data);
        else begin $display("FAIL: SOC_ID = %h (expected 56445030)", rd_data); errors=errors+1; end

        axi_read(12'h008, rd_data, rd_resp);
        if (rd_data === 32'b0010) // rf_link_up=1, others 0
            $display("PASS: SOC_STATUS = %b (rf_link_up=1, rest=0)", rd_data);
        else begin $display("FAIL: SOC_STATUS = %b (expected 0010)", rd_data); errors=errors+1; end

        // Test soft_reset_o pulses exactly 1 cycle on SOC_CTRL write
        fork
            axi_write(12'h004, 32'h0000_0001);
        join_none
        @(posedge clk);
        // soft_reset asserts during the commit cycle of the write
        wait (soft_reset === 1'b1);
        $display("PASS: soft_reset_o pulsed high on SOC_CTRL[0]=1 write");
        @(posedge clk);
        if (soft_reset === 1'b0)
            $display("PASS: soft_reset_o self-cleared after 1 cycle");
        else begin $display("FAIL: soft_reset_o still high (%b), expected self-clear", soft_reset); errors=errors+1; end

        // SOC_CTRL always reads back 0 (self-clearing / write-only semantics)
        axi_read(12'h004, rd_data, rd_resp);
        if (rd_data === 32'h0) $display("PASS: SOC_CTRL reads back 0");
        else begin $display("FAIL: SOC_CTRL readback = %h (expected 0)", rd_data); errors=errors+1; end

        // Change aggregated status and verify live passthrough
        sensor_alarm = 1'b1; vdp_frame_flag = 1'b1;
        @(posedge clk);
        axi_read(12'h008, rd_data, rd_resp);
        if (rd_data === 32'b1010)
            $display("PASS: SOC_STATUS reflects live sensor_alarm+vdp_frame_flag (%b)", rd_data);
        else begin $display("FAIL: SOC_STATUS = %b (expected 1010)", rd_data); errors=errors+1; end

        axi_read(12'h0F4, rd_data, rd_resp);
        if (rd_resp === 2'b10) $display("PASS: unmapped offset -> SLVERR");
        else begin $display("FAIL: unmapped offset resp=%b", rd_resp); errors=errors+1; end

        if (errors == 0) $display("==== TB_CONTROL_STATUS: ALL TESTS PASSED ====");
        else $display("==== TB_CONTROL_STATUS: %0d TEST(S) FAILED ====", errors);
        $finish;
    end

endmodule
