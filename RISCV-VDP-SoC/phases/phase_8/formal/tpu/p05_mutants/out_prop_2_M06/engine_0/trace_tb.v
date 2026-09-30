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
  reg [0:0] PI_bus_strb_0;
  reg [0:0] PI_bus_req;
  reg [0:0] PI_bus_write;
  reg [31:0] PI_bus_addr;
  reg [0:0] PI_bus_wdata_0;
  reg [0:0] PI_rst_n;
  wire [0:0] PI_clk = clock;
  reg [0:0] PI_m_axis_tready;
  tpu_p05_control_checker UUT (
    .bus_strb_0(PI_bus_strb_0),
    .bus_req(PI_bus_req),
    .bus_write(PI_bus_write),
    .bus_addr(PI_bus_addr),
    .bus_wdata_0(PI_bus_wdata_0),
    .rst_n(PI_rst_n),
    .clk(PI_clk),
    .m_axis_tready(PI_m_axis_tready)
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
    // UUT.$formal$tpu_p05_control_checker.\sv:69$115_EN  = 1'b0;
    UUT._witness_.anyinit_flatten_u_wrapper__u_master__procdff_2134 = 1'b0;
    UUT._witness_.anyinit_flatten_u_wrapper__u_master__procdff_2135 = 1'b0;
    UUT._witness_.anyinit_flatten_u_wrapper__u_master__procdff_2138 = 2'b00;
    UUT._witness_.anyinit_flatten_u_wrapper__u_master__procdff_2139 = 3'b000;
    UUT._witness_.anyinit_flatten_u_wrapper__u_wrapper__procdff_2141 = 1'b0;
    UUT._witness_.anyinit_flatten_u_wrapper__u_wrapper__procdff_2142 = 1'b0;
    UUT._witness_.anyinit_procdff_2123 = 1'b0;
    UUT._witness_.anyinit_procdff_2128 = 1'b0;
    UUT.init = 1'b1;
    UUT.past_valid = 1'b0;

    // state 0
    PI_bus_strb_0 = 1'b1;
    PI_bus_req = 1'b0;
    PI_bus_write = 1'b1;
    PI_bus_addr = 32'b00000000000000000000000000000000;
    PI_bus_wdata_0 = 1'b1;
    PI_rst_n = 1'b0;
    PI_m_axis_tready = 1'b0;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_bus_strb_0 <= 1'b1;
      PI_bus_req <= 1'b1;
      PI_bus_write <= 1'b1;
      PI_bus_addr <= 32'b00000000000000000000000000000000;
      PI_bus_wdata_0 <= 1'b1;
      PI_rst_n <= 1'b1;
      PI_m_axis_tready <= 1'b0;
    end

    // state 2
    if (cycle == 1) begin
      PI_bus_strb_0 <= 1'b1;
      PI_bus_req <= 1'b0;
      PI_bus_write <= 1'b1;
      PI_bus_addr <= 32'b00000000000000000000000000000000;
      PI_bus_wdata_0 <= 1'b1;
      PI_rst_n <= 1'b1;
      PI_m_axis_tready <= 1'b0;
    end

    // state 3
    if (cycle == 2) begin
      PI_bus_strb_0 <= 1'b1;
      PI_bus_req <= 1'b0;
      PI_bus_write <= 1'b1;
      PI_bus_addr <= 32'b00000000000000000000000000000000;
      PI_bus_wdata_0 <= 1'b1;
      PI_rst_n <= 1'b1;
      PI_m_axis_tready <= 1'b0;
    end

    // state 4
    if (cycle == 3) begin
      PI_bus_strb_0 <= 1'b1;
      PI_bus_req <= 1'b0;
      PI_bus_write <= 1'b1;
      PI_bus_addr <= 32'b00000000000000000000000000000000;
      PI_bus_wdata_0 <= 1'b1;
      PI_rst_n <= 1'b1;
      PI_m_axis_tready <= 1'b0;
    end

    genclock <= cycle < 4;
    cycle <= cycle + 1;
  end
endmodule
