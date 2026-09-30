module dut(input a, output b);
assign b = a;
endmodule
module tb;
dut d(.a(1'b1), .b());
always @* assert(d.b == 1'b1);
endmodule
