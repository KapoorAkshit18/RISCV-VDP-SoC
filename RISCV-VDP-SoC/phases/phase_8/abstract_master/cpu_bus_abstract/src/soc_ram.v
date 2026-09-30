`ifndef SOC_RAM_V
`define SOC_RAM_V

module soc_ram #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 256
)(
    input  wire                     clk,
    input  wire                     reset,

    input  wire                     valid,
    input  wire                     write,
    input  wire [ADDR_WIDTH-1:0]    addr,
    input  wire [DATA_WIDTH-1:0]    wdata,
    input  wire [DATA_WIDTH/8-1:0]  strb,

    output reg                      ready,
    output reg  [DATA_WIDTH-1:0]    rdata
);

    localparam WORD_ADDR_WIDTH = $clog2(DEPTH);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    wire [WORD_ADDR_WIDTH-1:0] word_addr;

    assign word_addr = addr[WORD_ADDR_WIDTH+1:2];

    always @(posedge clk) begin

        if (reset) begin
            ready <= 1'b0;
            rdata <= {DATA_WIDTH{1'b0}};
        end

        else begin
            ready <= 1'b0;

            if (valid) begin

                ready <= 1'b1;

                if (write) begin

                    if (strb[0])
                        mem[word_addr][7:0]   <= wdata[7:0];

                    if (strb[1])
                        mem[word_addr][15:8]  <= wdata[15:8];

                    if (strb[2])
                        mem[word_addr][23:16] <= wdata[23:16];

                    if (strb[3])
                        mem[word_addr][31:24] <= wdata[31:24];

                end

                else begin
                    rdata <= mem[word_addr];
                end
            end
        end
    end

endmodule

`endif