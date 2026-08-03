`timescale 1ns/1ps
// =============================================================================
// tb_sensor_status.v -- self-checking testbench for sensor_status_axi_slave
// Run with: iverilog -o sim_sensor tb_sensor_status.v ../rtl/sensor_status_axi_slave.v && vvp sim_sensor
// =============================================================================
module tb_sensor_status;

    reg clk = 0;
    reg rst_n;

    reg  [11:0] awaddr; reg awvalid; wire awready;
    reg  [31:0] wdata;  reg [3:0] wstrb; reg wvalid; wire wready;
    wire [1:0]  bresp;  wire bvalid; reg bready;
    reg  [11:0] araddr; reg arvalid; wire arready;
    wire [31:0] rdata;  wire [1:0] rresp; wire rvalid; reg rready;

    reg [7:0]  battery_percent;
    reg [15:0] battery_voltage;
    reg [15:0] temperature;
    reg        sensor_valid;

    integer errors = 0;

    sensor_status_axi_slave dut (
        .s_axi_aclk(clk), .s_axi_aresetn(rst_n),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .battery_percent_i(battery_percent),
        .battery_voltage_mv_i(battery_voltage),
        .temperature_tenthsC_i(temperature),
        .sensor_valid_i(sensor_valid)
    );

    always #5 clk = ~clk;

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
        battery_percent = 8'd67;
        battery_voltage = 16'd3700;   // 3700 mV
        temperature     = 16'sd235;   // 23.5 C
        sensor_valid    = 1'b1;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (6) @(posedge clk); // let 2-FF synchronizers settle

        axi_read(12'h000, rd_data, rd_resp);
        if (rd_data === 32'd67) $display("PASS: BATTERY_PERCENT = %0d", rd_data);
        else begin $display("FAIL: BATTERY_PERCENT = %0d (expected 67)", rd_data); errors=errors+1; end

        axi_read(12'h004, rd_data, rd_resp);
        if (rd_data === 32'd3700) $display("PASS: BATTERY_VOLTAGE = %0d mV", rd_data);
        else begin $display("FAIL: BATTERY_VOLTAGE = %0d (expected 3700)", rd_data); errors=errors+1; end

        axi_read(12'h008, rd_data, rd_resp);
        if (rd_data === 32'd235) $display("PASS: TEMPERATURE = %0d (tenths C)", rd_data);
        else begin $display("FAIL: TEMPERATURE = %0d (expected 235)", rd_data); errors=errors+1; end

        axi_read(12'h00C, rd_data, rd_resp);
        if (rd_data === 32'b001) // valid=1, battery_low=0(67>15), temp_alarm=0(23.5<80)
            $display("PASS: SENSOR_STATUS = %b (valid=1, batt_low=0, temp_alarm=0)", rd_data);
        else begin $display("FAIL: SENSOR_STATUS = %b (expected 001)", rd_data); errors=errors+1; end

        // Test low-battery alarm bit
        battery_percent = 8'd10;
        repeat (4) @(posedge clk);
        axi_read(12'h00C, rd_data, rd_resp);
        if (rd_data[1] === 1'b1)
            $display("PASS: battery_low asserted when percent=10 (SENSOR_STATUS=%b)", rd_data);
        else begin $display("FAIL: battery_low not asserted, SENSOR_STATUS=%b", rd_data); errors=errors+1; end

        // Test write is dropped (RO region) but bus does not hang
        @(posedge clk);
        awaddr <= 12'h000; awvalid <= 1'b1; wdata <= 32'hFFFF_FFFF; wstrb <= 4'hF; wvalid <= 1'b1; bready <= 1'b1;
        @(posedge clk);
        while (!(awready && wready)) @(posedge clk);
        awvalid <= 1'b0; wvalid <= 1'b0;
        while (!bvalid) @(posedge clk);
        if (bresp === 2'b00) $display("PASS: write to RO BATTERY_PERCENT accepted (BRESP=OKAY), value unchanged");
        else begin $display("FAIL: unexpected BRESP=%b on RO write", bresp); errors=errors+1; end
        @(posedge clk);
        axi_read(12'h000, rd_data, rd_resp);
        if (rd_data === 32'd10) $display("PASS: BATTERY_PERCENT unchanged by write (=%0d)", rd_data);
        else begin $display("FAIL: BATTERY_PERCENT changed to %0d", rd_data); errors=errors+1; end

        // Unmapped offset
        axi_read(12'h0F0, rd_data, rd_resp);
        if (rd_resp === 2'b10) $display("PASS: unmapped offset -> SLVERR");
        else begin $display("FAIL: unmapped offset resp=%b (expected SLVERR)", rd_resp); errors=errors+1; end

        if (errors == 0) $display("==== TB_SENSOR_STATUS: ALL TESTS PASSED ====");
        else $display("==== TB_SENSOR_STATUS: %0d TEST(S) FAILED ====", errors);
        $finish;
    end

endmodule
