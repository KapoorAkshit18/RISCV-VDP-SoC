module formal_cpu_master (
    input  wire        clk,
    input  wire        resetn,

    // Unconstrained formal inputs
    input  wire        f_valid,
    input  wire        f_instr,
    input  wire [31:0] f_addr,
    input  wire [31:0] f_wdata,
    input  wire [ 3:0] f_wstrb,

    // Bus interface matching CPU
    output reg         mem_valid,
    output reg         mem_instr,
    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_wdata,
    output reg  [ 3:0] mem_wstrb,

    input  wire        mem_ready,
    input  wire [31:0] mem_rdata
);
    // Simple state tracking
    reg in_flight;

    always @(posedge clk) begin
        if (!resetn) begin
            mem_valid <= 1'b0;
            mem_instr <= 1'b0;
            mem_addr  <= 32'b0;
            mem_wdata <= 32'b0;
            mem_wstrb <= 4'b0;
            in_flight <= 1'b0;
        end else begin
            if (in_flight) begin
                if (mem_ready) begin
                    // Transaction completed, start a new one if f_valid is high
                    mem_valid <= f_valid;
                    mem_instr <= f_instr;
                    mem_addr  <= f_addr;
                    mem_wdata <= f_wdata;
                    mem_wstrb <= f_wstrb;
                    in_flight <= f_valid;
                end else begin
                    // Still waiting for ready, outputs MUST remain completely stable
                    mem_valid <= mem_valid;
                    mem_instr <= mem_instr;
                    mem_addr  <= mem_addr;
                    mem_wdata <= mem_wdata;
                    mem_wstrb <= mem_wstrb;
                    in_flight <= 1'b1;
                end
            end else begin
                // Idle state, accept new symbolic inputs
                mem_valid <= f_valid;
                mem_instr <= f_instr;
                mem_addr  <= f_addr;
                mem_wdata <= f_wdata;
                mem_wstrb <= f_wstrb;
                in_flight <= f_valid;
            end
        end
    end

endmodule
