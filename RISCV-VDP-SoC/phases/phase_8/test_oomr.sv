module dut(input clk, input a, output b);
assign b = a;
wire internal_w = a ^ b;
endmodule

module tb;
wire clk, a, b;
dut d(.clk(clk), .a(a), .b(b));
always @(posedge clk) assert(d.internal_w == 1'b0);
endmodule
