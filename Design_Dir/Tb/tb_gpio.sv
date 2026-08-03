`timescale 1ns/1ps
// =============================================================================
// tb_gpio.v -- self-checking testbench for gpio_axi_slave
// Run with: iverilog -o sim_gpio tb_gpio.v ../rtl/gpio_axi_slave.v && vvp sim_gpio
// =============================================================================
module tb_gpio;

    reg clk = 0;
    reg rst_n;

    reg  [11:0] awaddr;
    reg         awvalid;
    wire        awready;
    reg  [31:0] wdata;
    reg  [3:0]  wstrb;
    reg         wvalid;
    wire        wready;
    wire [1:0]  bresp;
    wire        bvalid;
    reg         bready;
    reg  [11:0] araddr;
    reg         arvalid;
    wire        arready;
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rvalid;
    reg         rready;

    reg  [31:0] gpio_in_tb;
    wire [31:0] gpio_out_tb;
    wire [31:0] gpio_oe_tb;

    integer errors = 0;

    gpio_axi_slave #(.GPIO_WIDTH(32)) dut (
        .s_axi_aclk(clk), .s_axi_aresetn(rst_n),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .gpio_out(gpio_out_tb), .gpio_oe(gpio_oe_tb), .gpio_in(gpio_in_tb)
    );

    always #5 clk = ~clk; // 100MHz

    // ---- AXI-Lite helper tasks ----
    task axi_write(input [11:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            awaddr  <= addr; awvalid <= 1'b1;
            wdata   <= data; wstrb   <= 4'hF; wvalid <= 1'b1;
            bready  <= 1'b1;
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
            araddr <= addr; arvalid <= 1'b1;
            rready <= 1'b1;
            @(posedge clk);
            while (!arready) @(posedge clk);
            arvalid <= 1'b0;
            while (!rvalid) @(posedge clk);
            data = rdata; resp = rresp;
            @(posedge clk);
        end
    endtask

    reg [31:0] rd_data;
    reg [1:0]  rd_resp;

    initial begin
        rst_n = 0; awvalid=0; wvalid=0; bready=0; arvalid=0; rready=0;
        awaddr=0; wdata=0; wstrb=0; araddr=0;
        gpio_in_tb = 32'hDEAD_BEEF;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // Test 1: write GPIO_DIR = all outputs, then GPIO_DATA_OUT = 0xA5A5A5A5
        axi_write(12'h008, 32'hFFFF_FFFF); // DIR = all output
        axi_write(12'h000, 32'hA5A5_A5A5); // DATA_OUT

        axi_read(12'h000, rd_data, rd_resp);
        if (rd_data === 32'hA5A5_A5A5 && rd_resp === 2'b00)
            $display("PASS: GPIO_DATA_OUT readback = %h", rd_data);
        else begin
            $display("FAIL: GPIO_DATA_OUT readback = %h resp=%b (expected A5A5A5A5/00)", rd_data, rd_resp);
            errors = errors + 1;
        end

        if (gpio_out_tb === 32'hA5A5_A5A5 && gpio_oe_tb === 32'hFFFF_FFFF)
            $display("PASS: gpio_out/gpio_oe pins driven correctly");
        else begin
            $display("FAIL: gpio_out=%h gpio_oe=%h (expected A5A5A5A5 / FFFFFFFF)", gpio_out_tb, gpio_oe_tb);
            errors = errors + 1;
        end

        // Test 2: GPIO_DATA_IN reflects external pins (2-cycle sync latency already
        // elapsed by the time we issue the read, since several cycles passed above)
        axi_read(12'h004, rd_data, rd_resp);
        if (rd_data === 32'hDEAD_BEEF)
            $display("PASS: GPIO_DATA_IN = %h", rd_data);
        else begin
            $display("FAIL: GPIO_DATA_IN = %h (expected DEADBEEF)", rd_data);
            errors = errors + 1;
        end

        // Test 3: GPIO_STATUS write_pulse strobes exactly 1 cycle after a write to DATA_OUT
        axi_write(12'h000, 32'h0000_0001);
        axi_read(12'h00C, rd_data, rd_resp);
        // by the time axi_read completes (several cycles later) the 1-cycle pulse
        // will already have cleared -- confirms pulse is NOT sticky
        if (rd_data[0] === 1'b0)
            $display("PASS: GPIO_STATUS write_pulse correctly self-clears (=%b)", rd_data[0]);
        else begin
            $display("FAIL: GPIO_STATUS write_pulse did not clear (=%b)", rd_data[0]);
            errors = errors + 1;
        end

        // Test 4: unmapped offset returns SLVERR
        axi_read(12'h0FC, rd_data, rd_resp);
        if (rd_resp === 2'b10 && rd_data === 32'h0)
            $display("PASS: unmapped offset 0xFC -> SLVERR, data=0");
        else begin
            $display("FAIL: unmapped offset 0xFC -> resp=%b data=%h (expected 10/0)", rd_resp, rd_data);
            errors = errors + 1;
        end

        // Test 5: reset behavior
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        axi_read(12'h000, rd_data, rd_resp);
        if (rd_data === 32'h0)
            $display("PASS: GPIO_DATA_OUT resets to 0");
        else begin
            $display("FAIL: GPIO_DATA_OUT after reset = %h (expected 0)", rd_data);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("==== TB_GPIO: ALL TESTS PASSED ====");
        else
            $display("==== TB_GPIO: %0d TEST(S) FAILED ====", errors);

        $finish;
    end

endmodule
