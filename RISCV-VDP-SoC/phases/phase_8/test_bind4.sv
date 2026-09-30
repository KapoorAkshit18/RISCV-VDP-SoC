module dut(input clk, input a, output b);
assign b = a;
wire internal_w = a ^ b;
endmodule

module props(input clk, input internal_w);
always @(posedge clk) assert(internal_w == 1'b0);
endmodule

bind dut props p(.clk(clk), .internal_w(internal_w));

module tb;
wire clk;
wire a;
wire b;
dut d(.clk(clk), .a(a), .b(b));
endmodule
