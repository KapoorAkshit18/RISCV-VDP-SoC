`ifndef VERILATOR
module testbench;
  reg [4095:0] vcdfile;
  reg clock;
`else
module testbench(input clock, output reg genclock);
  initial genclock = 1;
`endif
  reg genclock = 1;
  reg [31:0] cycle = 0;
  reg [31:0] PI_mem_wdata;
  reg [7:0] PI_battery_percent_i;
  reg [0:0] PI_resetn;
  reg [15:0] PI_temperature_tenthsC_i;
  reg [0:0] PI_mem_valid;
  reg [0:0] PI_sensor_valid_i;
  reg [15:0] PI_battery_voltage_mv_i;
  reg [0:0] PI_mem_instr;
  reg [11:0] PI_mem_addr;
  wire [0:0] PI_clk = clock;
  reg [3:0] PI_mem_wstrb;
  sensor_formal_cover_top UUT (
    .mem_wdata(PI_mem_wdata),
    .battery_percent_i(PI_battery_percent_i),
    .resetn(PI_resetn),
    .temperature_tenthsC_i(PI_temperature_tenthsC_i),
    .mem_valid(PI_mem_valid),
    .sensor_valid_i(PI_sensor_valid_i),
    .battery_voltage_mv_i(PI_battery_voltage_mv_i),
    .mem_instr(PI_mem_instr),
    .mem_addr(PI_mem_addr),
    .clk(PI_clk),
    .mem_wstrb(PI_mem_wstrb)
  );
`ifndef VERILATOR
  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
    #5 clock = 0;
    while (genclock) begin
      #5 clock = 0;
      #5 clock = 1;
    end
  end
`endif
  initial begin
`ifndef VERILATOR
    #1;
`endif
    // UUT.$formal$sensor_cover_top.\sv:97$37_EN  = 1'b0;
    UUT._witness_.anyinit_procdff_171 = 1'b0;
    UUT.dut.batt_pct_ff1 = 8'b00000000;
    UUT.dut.batt_pct_sync = 8'b00000000;
    UUT.dut.batt_volt_ff1 = 16'b0000000000000000;
    UUT.dut.batt_volt_sync = 16'b0000000000000000;
    UUT.dut.mem_rdata = 32'b00000000000000000000000000000000;
    UUT.dut.mem_ready = 1'b0;
    UUT.dut.pending_request = 1'b0;
    UUT.dut.response_data = 32'b00000000000000000000000000000000;
    UUT.dut.temp_ff1 = 16'b0000000000000000;
    UUT.dut.temp_sync = 16'b0000000000000000;
    UUT.dut.valid_ff1 = 1'b0;
    UUT.dut.valid_sync = 1'b0;
    UUT.rst_step = 3'b000;
    UUT.temp_ff1 = 16'b0000000000000000;
    UUT.temp_sync = 16'b0000000000000000;

    // state 0
    PI_mem_wdata = 32'b00000000000000000000000000000000;
    PI_battery_percent_i = 8'b00000000;
    PI_resetn = 1'b0;
    PI_temperature_tenthsC_i = 16'b0000000000000000;
    PI_mem_valid = 1'b0;
    PI_sensor_valid_i = 1'b0;
    PI_battery_voltage_mv_i = 16'b0000000000000000;
    PI_mem_instr = 1'b0;
    PI_mem_addr = 12'b000000001100;
    PI_mem_wstrb = 4'b0000;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_mem_wdata <= 32'b00000000000000000000000000000000;
      PI_battery_percent_i <= 8'b00000000;
      PI_resetn <= 1'b0;
      PI_temperature_tenthsC_i <= 16'b0000000000000000;
      PI_mem_valid <= 1'b0;
      PI_sensor_valid_i <= 1'b0;
      PI_battery_voltage_mv_i <= 16'b0000000000000000;
      PI_mem_instr <= 1'b0;
      PI_mem_addr <= 12'b000000001100;
      PI_mem_wstrb <= 4'b0000;
    end

    // state 2
    if (cycle == 1) begin
      PI_mem_wdata <= 32'b00000000000000000000000000000000;
      PI_battery_percent_i <= 8'b00010000;
      PI_resetn <= 1'b1;
      PI_temperature_tenthsC_i <= 16'b1111111111111111;
      PI_mem_valid <= 1'b0;
      PI_sensor_valid_i <= 1'b0;
      PI_battery_voltage_mv_i <= 16'b0000000000000001;
      PI_mem_instr <= 1'b0;
      PI_mem_addr <= 12'b000000001100;
      PI_mem_wstrb <= 4'b0000;
    end

    // state 3
    if (cycle == 2) begin
      PI_mem_wdata <= 32'b00000000000000000000000000000000;
      PI_battery_percent_i <= 8'b00000000;
      PI_resetn <= 1'b1;
      PI_temperature_tenthsC_i <= 16'b0000000000000000;
      PI_mem_valid <= 1'b0;
      PI_sensor_valid_i <= 1'b0;
      PI_battery_voltage_mv_i <= 16'b0000000000000000;
      PI_mem_instr <= 1'b0;
      PI_mem_addr <= 12'b000000001100;
      PI_mem_wstrb <= 4'b0000;
    end

    // state 4
    if (cycle == 3) begin
      PI_mem_wdata <= 32'b00000000000000000000000000000000;
      PI_battery_percent_i <= 8'b00000000;
      PI_resetn <= 1'b1;
      PI_temperature_tenthsC_i <= 16'b0000000000000000;
      PI_mem_valid <= 1'b0;
      PI_sensor_valid_i <= 1'b0;
      PI_battery_voltage_mv_i <= 16'b0000000000000000;
      PI_mem_instr <= 1'b0;
      PI_mem_addr <= 12'b000000000100;
      PI_mem_wstrb <= 4'b0000;
    end

    // state 5
    if (cycle == 4) begin
      PI_mem_wdata <= 32'b00000000000000000000000000000000;
      PI_battery_percent_i <= 8'b00000000;
      PI_resetn <= 1'b1;
      PI_temperature_tenthsC_i <= 16'b0000000000000000;
      PI_mem_valid <= 1'b0;
      PI_sensor_valid_i <= 1'b0;
      PI_battery_voltage_mv_i <= 16'b0000000000000000;
      PI_mem_instr <= 1'b0;
      PI_mem_addr <= 12'b000000001100;
      PI_mem_wstrb <= 4'b0000;
    end

    genclock <= cycle < 5;
    cycle <= cycle + 1;
  end
endmodule
