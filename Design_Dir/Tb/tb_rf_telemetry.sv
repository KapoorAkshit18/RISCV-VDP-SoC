`timescale 1ns/1ps
// =============================================================================
// tb_rf_telemetry.v -- self-checking testbench for rf_telemetry_axi_slave
// Run with: iverilog -o sim_rf tb_rf_telemetry.v ../rtl/rf_telemetry_axi_slave.v && vvp sim_rf
// =============================================================================
module tb_rf_telemetry;

    reg clk = 0;
    reg rst_n;

    reg  [11:0] awaddr; reg awvalid; wire awready;
    reg  [31:0] wdata;  reg [3:0] wstrb; reg wvalid; wire wready;
    wire [1:0]  bresp;  wire bvalid; reg bready;
    reg  [11:0] araddr; reg arvalid; wire arready;
    wire [31:0] rdata;  wire [1:0] rresp; wire rvalid; reg rready;

    reg [7:0] rssi_dbm;
    reg link_up, link_error, carrier_detect;
    wire rf_enable;

    integer errors = 0;

    rf_telemetry_axi_slave dut (
        .s_axi_aclk(clk), .s_axi_aresetn(rst_n),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .rssi_dbm_i(rssi_dbm), .link_up_i(link_up), .link_error_i(link_error),
        .carrier_detect_i(carrier_detect), .rf_enable_o(rf_enable)
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
        rssi_dbm = -8'd62 /* wraps to 8'b11000010 = -62 in two's complement */;
        link_up = 1'b1; link_error = 1'b0; carrier_detect = 1'b1;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (6) @(posedge clk);

        axi_read(12'h000, rd_data, rd_resp);
        if ($signed(rd_data[7:0]) === -8'sd62)
            $display("PASS: RF_RSSI = %0d dBm", $signed(rd_data[7:0]));
        else begin $display("FAIL: RF_RSSI = %0d (expected -62)", $signed(rd_data[7:0])); errors=errors+1; end

        axi_read(12'h004, rd_data, rd_resp);
        if (rd_data === 32'b101) // carrier=1, err=0, up=1
            $display("PASS: RF_LINK_STAT = %b (link_up=1, err=0, carrier=1)", rd_data);
        else begin $display("FAIL: RF_LINK_STAT = %b (expected 101)", rd_data); errors=errors+1; end

        axi_read(12'h00C, rd_data, rd_resp);
        if (rd_data === 32'h5246_5430)
            $display("PASS: RF_ID = %h (\"RFT0\")", rd_data);
        else begin $display("FAIL: RF_ID = %h (expected 52465430)", rd_data); errors=errors+1; end

        // Test RF_CONTROL R/W and rf_enable_o pin
        axi_write(12'h008, 32'h0000_0001);
        if (rf_enable === 1'b1)
            $display("PASS: rf_enable_o pin asserted after RF_CONTROL write");
        else begin $display("FAIL: rf_enable_o = %b (expected 1)", rf_enable); errors=errors+1; end

        axi_read(12'h008, rd_data, rd_resp);
        if (rd_data === 32'h1)
            $display("PASS: RF_CONTROL readback = %h", rd_data);
        else begin $display("FAIL: RF_CONTROL readback = %h (expected 1)", rd_data); errors=errors+1; end

        axi_read(12'h0A0, rd_data, rd_resp);
        if (rd_resp === 2'b10) $display("PASS: unmapped offset -> SLVERR");
        else begin $display("FAIL: unmapped offset resp=%b", rd_resp); errors=errors+1; end

        if (errors == 0) $display("==== TB_RF_TELEMETRY: ALL TESTS PASSED ====");
        else $display("==== TB_RF_TELEMETRY: %0d TEST(S) FAILED ====", errors);
        $finish;
    end

endmodule
