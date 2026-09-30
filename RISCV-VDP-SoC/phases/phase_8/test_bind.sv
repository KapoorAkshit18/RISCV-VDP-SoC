module dut(input clk, input a, output b);
assign b = a;
endmodule
module props(input clk, input a, input b);
always @(posedge clk) assert(a == b);
endmodule
bind dut props p(.clk(clk), .a(a), .b(b));
