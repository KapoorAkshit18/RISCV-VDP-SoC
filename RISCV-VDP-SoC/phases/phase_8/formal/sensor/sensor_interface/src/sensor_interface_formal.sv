module sensor_bind_formal (
    input clk,
    input resetn,
    input mem_valid,
    input [3:0] mem_wstrb,
    input [11:0] mem_addr,
    input mem_ready,
    input [31:0] mem_rdata,
    input [7:0] batt_pct_sync,
    input [15:0] temp_sync,
    input battery_low,
    input temp_alarm,
    input pending_request
);

    reg init = 1'b1;
    always @(posedge clk) init <= 1'b0;

    // SEN_AS01: Reset initialization.
    always @(*) if (init) assume(!resetn);

    always @(posedge clk) begin
        if (!init && resetn) begin
            // SEN_A01: Read-only behavior.
            if ($past(mem_valid) && $past(mem_wstrb != 4'b0) && !$past(pending_request)) begin
                assert(mem_ready == 1'b1);
                assert(mem_rdata == 32'b0);
            end

            // SEN_A02: Battery low logic threshold correctness.
            assert(battery_low == (batt_pct_sync <= 8'd15));

            // SEN_A03: Temperature alarm logic threshold correctness.
            assert(temp_alarm == ($signed(temp_sync) > 16'sd800));

            // SEN_A04: Unmapped access read behavior.
            if ($past(mem_valid) && $past(mem_wstrb == 4'b0) && !$past(pending_request) &&
                ($past(mem_addr) != 12'h000) && ($past(mem_addr) != 12'h004) && 
                ($past(mem_addr) != 12'h008) && ($past(mem_addr) != 12'h00C)) begin
                assert(mem_ready == 1'b1);
                assert(mem_rdata == 32'b0);
            end
        end
    end

    always @(posedge clk) begin
        if (resetn && !init) begin
            // SEN_C01: Battery low boundary coverage (BATT_LOW_THRESH - 1)
            cover(batt_pct_sync == 8'd14);
            // SEN_C02: Battery low boundary coverage (BATT_LOW_THRESH)
            cover(batt_pct_sync == 8'd15);
            // SEN_C03: Battery low boundary coverage (BATT_LOW_THRESH + 1)
            cover(batt_pct_sync == 8'd16);

            // SEN_C04: Temperature high boundary (TEMP_ALARM_HIGH - 1)
            cover(temp_sync == 16'sd799);
            // SEN_C05: Temperature high boundary (TEMP_ALARM_HIGH)
            cover(temp_sync == 16'sd800);
            // SEN_C06: Temperature high boundary (TEMP_ALARM_HIGH + 1)
            cover(temp_sync == 16'sd801);
            
            // SEN_C07: Signed negative temperature
            cover(temp_sync == 16'hFFFF);
            
            // SEN_C08: Unmapped read execution
            cover($past(mem_valid) && $past(mem_wstrb == 4'b0) && ($past(mem_addr) == 12'h010) && mem_ready);
        end
    end
endmodule

bind sensor_status_native_slave sensor_bind_formal u_checker (
    .clk(clk),
    .resetn(resetn),
    .mem_valid(mem_valid),
    .mem_wstrb(mem_wstrb),
    .mem_addr(mem_addr),
    .mem_ready(mem_ready),
    .mem_rdata(mem_rdata),
    .batt_pct_sync(batt_pct_sync),
    .temp_sync(temp_sync),
    .battery_low(battery_low),
    .temp_alarm(temp_alarm),
    .pending_request(pending_request)
);

module sensor_interface_formal (
    input  wire        clk,
    input  wire        resetn,
    input  wire        mem_valid,
    input  wire        mem_instr,
    input  wire [11:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,
    input  wire [7:0]  battery_percent_i,
    input  wire [15:0] battery_voltage_mv_i,
    input  wire [15:0] temperature_tenthsC_i,
    input  wire        sensor_valid_i,
    output wire        mem_ready,
    output wire [31:0] mem_rdata
);
    sensor_status_native_slave dut (
        .clk                   (clk),
        .resetn                (resetn),
        .mem_valid             (mem_valid),
        .mem_instr             (mem_instr),
        .mem_ready             (mem_ready),
        .mem_addr              (mem_addr),
        .mem_wdata             (mem_wdata),
        .mem_wstrb             (mem_wstrb),
        .mem_rdata             (mem_rdata),
        .battery_percent_i     (battery_percent_i),
        .battery_voltage_mv_i  (battery_voltage_mv_i),
        .temperature_tenthsC_i (temperature_tenthsC_i),
        .sensor_valid_i        (sensor_valid_i)
    );
endmodule
