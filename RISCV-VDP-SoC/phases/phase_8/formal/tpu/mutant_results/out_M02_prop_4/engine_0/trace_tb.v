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
  reg [0:0] PI_rst_n;
  reg [0:0] PI_axis_start;
  reg [63:0] PI_data_in;
  reg [0:0] PI_m_axis_tready;
  tpu_axis_checker UUT (
    .clk(PI_clk),
    .rst_n(PI_rst_n),
    .axis_start(PI_axis_start),
    .data_in(PI_data_in),
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
    // UUT.$formal$tpu_axis_checker.\sv:95$51_EN  = 1'b0;
    UUT._witness_.anyinit_flatten_u_master__procdff_211 = 2'b01;
    UUT._witness_.anyinit_flatten_u_master__procdff_212 = 3'b000;
    UUT._witness_.anyinit_procdff_202 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    UUT._witness_.anyinit_procdff_205 = 1'b1;
    UUT.init = 1'b1;

    // state 0
    PI_rst_n = 1'b0;
    PI_axis_start = 1'b0;
    PI_data_in = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    PI_m_axis_tready = 1'b1;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_rst_n <= 1'b1;
      PI_axis_start <= 1'b1;
      PI_data_in <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_m_axis_tready <= 1'b1;
    end

    // state 2
    if (cycle == 1) begin
      PI_rst_n <= 1'b1;
      PI_axis_start <= 1'b0;
      PI_data_in <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_m_axis_tready <= 1'b1;
    end

    // state 3
    if (cycle == 2) begin
      PI_rst_n <= 1'b1;
      PI_axis_start <= 1'b1;
      PI_data_in <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_m_axis_tready <= 1'b1;
    end

    // state 4
    if (cycle == 3) begin
      PI_rst_n <= 1'b1;
      PI_axis_start <= 1'b0;
      PI_data_in <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_m_axis_tready <= 1'b1;
    end

    // state 5
    if (cycle == 4) begin
      PI_rst_n <= 1'b1;
      PI_axis_start <= 1'b0;
      PI_data_in <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_m_axis_tready <= 1'b1;
    end

    // state 6
    if (cycle == 5) begin
      PI_rst_n <= 1'b1;
      PI_axis_start <= 1'b0;
      PI_data_in <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_m_axis_tready <= 1'b1;
    end

    // state 7
    if (cycle == 6) begin
      PI_rst_n <= 1'b1;
      PI_axis_start <= 1'b0;
      PI_data_in <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_m_axis_tready <= 1'b0;
    end

    // state 8
    if (cycle == 7) begin
      PI_rst_n <= 1'b0;
      PI_axis_start <= 1'b0;
      PI_data_in <= 64'b0000000000000000000000000000000000000001000000000000000000000000;
      PI_m_axis_tready <= 1'b1;
    end

    genclock <= cycle < 8;
    cycle <= cycle + 1;
  end
endmodule
