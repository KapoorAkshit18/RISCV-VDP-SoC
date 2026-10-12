// Direct formal verification model for sensor status slave covers SEN_C01 - SEN_C08
module sensor_formal_cover_top (
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
    parameter COVER_ID = 1;

    // Threshold constants
    localparam [7:0]  BATT_LOW_THRESH = 8'd15;
    localparam signed [15:0] TEMP_ALARM_HIGH = 16'sd800;

    // 2-FF synchronizers (exact replica matching sensor_status_native_slave.v)
    reg [7:0]  batt_pct_ff1,  batt_pct_sync;
    reg [15:0] batt_volt_ff1, batt_volt_sync;
    reg [15:0] temp_ff1,      temp_sync;
    reg        valid_ff1,     valid_sync;

    always @(posedge clk) begin
        if (!resetn) begin
            batt_pct_ff1  <= 8'h00;
            batt_pct_sync <= 8'h00;
            batt_volt_ff1  <= 16'h0000;
            batt_volt_sync <= 16'h0000;
            temp_ff1  <= 16'h0000;
            temp_sync <= 16'h0000;
            valid_ff1  <= 1'b0;
            valid_sync <= 1'b0;
        end else begin
            batt_pct_ff1  <= battery_percent_i;
            batt_pct_sync <= batt_pct_ff1;
            batt_volt_ff1  <= battery_voltage_mv_i;
            batt_volt_sync <= batt_volt_ff1;
            temp_ff1  <= temperature_tenthsC_i;
            temp_sync <= temp_ff1;
            valid_ff1  <= sensor_valid_i;
            valid_sync <= valid_ff1;
        end
    end

    // DUT instantiation
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

    reg [2:0] rst_step = 0;
    always @(posedge clk) if (rst_step < 5) rst_step <= rst_step + 1;

    always @(*) begin
        if (rst_step < 2) assume(!resetn);
        else assume(resetn);
    end

    always @(posedge clk) begin
        if (resetn && (rst_step >= 2)) begin
            // SEN_C01: Battery low boundary (14%)
            if (COVER_ID == 1) cover(batt_pct_sync == 8'd14);

            // SEN_C02: Battery low threshold boundary (15%)
            if (COVER_ID == 2) cover(batt_pct_sync == 8'd15);

            // SEN_C03: Battery low boundary (16%)
            if (COVER_ID == 3) cover(batt_pct_sync == 8'd16);

            // SEN_C04: Temperature high boundary (79.9 deg C)
            if (COVER_ID == 4) cover(temp_sync == 16'sd799);

            // SEN_C05: Temperature high boundary (80.0 deg C)
            if (COVER_ID == 5) cover(temp_sync == 16'sd800);

            // SEN_C06: Temperature high boundary (80.1 deg C)
            if (COVER_ID == 6) cover(temp_sync == 16'sd801);

            // SEN_C07: Signed negative temperature
            if (COVER_ID == 7) cover(temp_sync == 16'hFFFF);

            // SEN_C08: Unmapped read execution completing with mem_ready
            if (COVER_ID == 8) cover($past(mem_valid) && $past(mem_wstrb == 4'b0) && ($past(mem_addr) == 12'h010) && mem_ready);
        end
    end

endmodule
