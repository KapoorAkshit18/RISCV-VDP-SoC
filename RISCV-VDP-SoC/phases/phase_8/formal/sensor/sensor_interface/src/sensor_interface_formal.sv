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
    input pending_request
);

    reg init = 1'b1;
    always @(posedge clk) init <= 1'b0;

    // SEN_AS01: Reset initialization
    always @(*) if (init) assume(!resetn);
    always @(*) if (!init) assume(resetn);
    always @(*) if (!resetn) assume(!mem_valid);

    // Track when 2-cycle history is valid
    reg [2:0] rst_cnt = 3'd0;
    always @(posedge clk) begin
        if (!resetn) rst_cnt <= 3'd0;
        else if (rst_cnt < 3'd4) rst_cnt <= rst_cnt + 3'd1;
    end
    wire past2_valid = (rst_cnt >= 3'd3);

    // Native bus protocol: requests accepted only when slave is idle
    always @(posedge clk) begin
        if (pending_request || mem_ready) assume(!mem_valid);
    end

    always @(posedge clk) begin
        if (past2_valid && resetn) begin
            // Whenever slave completes transaction, mem_ready must assert
            if ($past(pending_request)) begin
                assert(mem_ready == 1'b1);
            end

            // SEN_A01: Read-only behavior: writes return ready=1 and rdata=0
            if ($past(pending_request) && $past(mem_valid, 2) && ($past(mem_wstrb, 2) != 4'b0)) begin
                assert(mem_ready == 1'b1);
                assert(mem_rdata == 32'b0);
            end

            // SEN_A02 & SEN_A03: Readback of DUT status register at local offset 0x00C
            // Compares bit 1 (battery_low) and bit 2 (temp_alarm) against expected threshold logic
            if ($past(pending_request) && $past(mem_valid, 2) && ($past(mem_wstrb, 2) == 4'b0) && ($past(mem_addr, 2) == 12'h00C)) begin
                assert(mem_ready == 1'b1);
                // SEN_A02: Battery-low flag in DUT status word
                assert(mem_rdata[1] == $past(batt_pct_sync <= 8'd15, 2));
                // SEN_A03: Temperature-alarm flag in DUT status word
                assert(mem_rdata[2] == $past($signed(temp_sync) > 16'sd800, 2));
            end

            // SEN_A04: Unmapped access read behavior: unmapped reads return ready=1 and rdata=0
            if ($past(pending_request) && $past(mem_valid, 2) && ($past(mem_wstrb, 2) == 4'b0) &&
                ($past(mem_addr, 2) != 12'h000) && ($past(mem_addr, 2) != 12'h004) && 
                ($past(mem_addr, 2) != 12'h008) && ($past(mem_addr, 2) != 12'h00C)) begin
                assert(mem_ready == 1'b1);
                assert(mem_rdata == 32'b0);
            end
        end
    end
endmodule

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
    // -------------------------------------------------------------
    // DUT Instance
    // -------------------------------------------------------------
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

    // -------------------------------------------------------------
    // Synchronizers & Request Tracking
    // -------------------------------------------------------------
    reg [7:0]  batt_pct_ff1,  batt_pct_sync;
    reg [15:0] batt_volt_ff1, batt_volt_sync;
    reg [15:0] temp_ff1,      temp_sync;
    reg        valid_ff1,     valid_sync;
    reg        pending_request;

    always @(posedge clk) begin
        if (!resetn) begin
            batt_pct_ff1    <= 8'h00;
            batt_pct_sync   <= 8'h00;
            batt_volt_ff1   <= 16'h0000;
            batt_volt_sync  <= 16'h0000;
            temp_ff1        <= 16'h0000;
            temp_sync       <= 16'h0000;
            valid_ff1       <= 1'b0;
            valid_sync      <= 1'b0;
            pending_request <= 1'b0;
        end else begin
            batt_pct_ff1    <= battery_percent_i;
            batt_pct_sync   <= batt_pct_ff1;
            batt_volt_ff1   <= battery_voltage_mv_i;
            batt_volt_sync  <= batt_volt_ff1;
            temp_ff1        <= temperature_tenthsC_i;
            temp_sync       <= temp_ff1;
            valid_ff1       <= sensor_valid_i;
            valid_sync      <= valid_ff1;
            if (pending_request)
                pending_request <= 1'b0;
            else if (mem_valid)
                pending_request <= 1'b1;
        end
    end

    // -------------------------------------------------------------
    // Formal Checker Connection (Directly checking DUT readback)
    // -------------------------------------------------------------
    sensor_bind_formal u_checker (
        .clk             (clk),
        .resetn          (resetn),
        .mem_valid       (mem_valid),
        .mem_wstrb       (mem_wstrb),
        .mem_addr        (mem_addr),
        .mem_ready       (mem_ready),
        .mem_rdata       (mem_rdata),
        .batt_pct_sync   (batt_pct_sync),
        .temp_sync       (temp_sync),
        .pending_request (pending_request)
    );

endmodule
