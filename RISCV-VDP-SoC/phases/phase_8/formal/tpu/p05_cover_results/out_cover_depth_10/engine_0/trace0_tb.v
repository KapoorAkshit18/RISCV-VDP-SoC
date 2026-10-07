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
  reg [0:0] PI_bus_wdata_0;
  reg [0:0] PI_m_axis_tready;
  reg [0:0] PI_bus_write;
  reg [0:0] PI_bus_strb_0;
  reg [0:0] PI_bus_req;
  reg [31:0] PI_bus_addr;
  wire [0:0] PI_clk = clock;
  reg [0:0] PI_rst_n;
  tpu_p05_control_checker UUT (
    .bus_wdata_0(PI_bus_wdata_0),
    .m_axis_tready(PI_m_axis_tready),
    .bus_write(PI_bus_write),
    .bus_strb_0(PI_bus_strb_0),
    .bus_req(PI_bus_req),
    .bus_addr(PI_bus_addr),
    .clk(PI_clk),
    .rst_n(PI_rst_n)
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
    // UUT.$formal$tpu_p05_control_checker.\sv:100$48_EN  = 1'b0;
    UUT._witness_.anyinit_flatten_u_wrapper__u_master__procdff_2074 = 1'b0;
    UUT._witness_.anyinit_flatten_u_wrapper__u_master__procdff_2075 = 1'b0;
    UUT._witness_.anyinit_flatten_u_wrapper__u_master__procdff_2078 = 2'b00;
    UUT._witness_.anyinit_flatten_u_wrapper__u_master__procdff_2079 = 3'b000;
    UUT._witness_.anyinit_flatten_u_wrapper__u_wrapper__procdff_2081 = 1'b0;
    UUT._witness_.anyinit_flatten_u_wrapper__u_wrapper__procdff_2082 = 1'b0;
    UUT._witness_.anyinit_procdff_2059 = 1'b0;
    UUT._witness_.anyinit_procdff_2061 = 1'b0;
    UUT.init = 1'b1;

    // state 0
    PI_bus_wdata_0 = 1'b1;
    PI_m_axis_tready = 1'b0;
    PI_bus_write = 1'b1;
    PI_bus_strb_0 = 1'b1;
    PI_bus_req = 1'b0;
    PI_bus_addr = 32'b00000000000000000000000000000000;
    PI_rst_n = 1'b0;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_bus_wdata_0 <= 1'b1;
      PI_m_axis_tready <= 1'b0;
      PI_bus_write <= 1'b1;
      PI_bus_strb_0 <= 1'b1;
      PI_bus_req <= 1'b1;
      PI_bus_addr <= 32'b00000000000000000000000000000000;
      PI_rst_n <= 1'b1;
    end

    // state 2
    if (cycle == 1) begin
      PI_bus_wdata_0 <= 1'b1;
      PI_m_axis_tready <= 1'b0;
      PI_bus_write <= 1'b1;
      PI_bus_strb_0 <= 1'b1;
      PI_bus_req <= 1'b0;
      PI_bus_addr <= 32'b00000000000000000000000000000000;
      PI_rst_n <= 1'b1;
    end

    // state 3
    if (cycle == 2) begin
      PI_bus_wdata_0 <= 1'b1;
      PI_m_axis_tready <= 1'b0;
      PI_bus_write <= 1'b1;
      PI_bus_strb_0 <= 1'b1;
      PI_bus_req <= 1'b0;
      PI_bus_addr <= 32'b00000000000000000000000000000000;
      PI_rst_n <= 1'b1;
    end

    genclock <= cycle < 3;
    cycle <= cycle + 1;
  end
endmodule
