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
  wire [0:0] PI_clk = clock;
  reg [0:0] PI_axis_start;
  reg [0:0] PI_m_axis_tready;
  reg [0:0] PI_rst_n;
  reg [63:0] PI_data_in;
  tpu_axis_checker UUT (
    .clk(PI_clk),
    .axis_start(PI_axis_start),
    .m_axis_tready(PI_m_axis_tready),
    .rst_n(PI_rst_n),
    .data_in(PI_data_in)
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
    // UUT.$formal$tpu_axis_checker.\sv:81$58_EN  = 1'b0;
    UUT._witness_.anyinit_flatten_u_master__procdff_224 = 2'b01;
    UUT._witness_.anyinit_flatten_u_master__procdff_225 = 3'b000;
    UUT._witness_.anyinit_procdff_212 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    UUT._witness_.anyinit_procdff_215 = 1'b0;
    UUT._witness_.anyinit_procdff_216 = 1'b0;
    UUT._witness_.anyinit_procdff_217 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    UUT._witness_.anyinit_procdff_218 = 1'b0;
    UUT.init = 1'b1;

    // state 0
    PI_axis_start = 1'b0;
    PI_m_axis_tready = 1'b0;
    PI_rst_n = 1'b0;
    PI_data_in = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_axis_start <= 1'b1;
      PI_m_axis_tready <= 1'b0;
      PI_rst_n <= 1'b1;
      PI_data_in <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
    end

    // state 2
    if (cycle == 1) begin
      PI_axis_start <= 1'b0;
      PI_m_axis_tready <= 1'b0;
      PI_rst_n <= 1'b1;
      PI_data_in <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
    end

    // state 3
    if (cycle == 2) begin
      PI_axis_start <= 1'b0;
      PI_m_axis_tready <= 1'b1;
      PI_rst_n <= 1'b1;
      PI_data_in <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
    end

    // state 4
    if (cycle == 3) begin
      PI_axis_start <= 1'b0;
      PI_m_axis_tready <= 1'b0;
      PI_rst_n <= 1'b0;
      PI_data_in <= 64'b0000000000000000000000000000000000000000000000000100000000000000;
    end

    genclock <= cycle < 4;
    cycle <= cycle + 1;
  end
endmodule
