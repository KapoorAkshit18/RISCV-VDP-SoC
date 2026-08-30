// =============================================================================
// gpio_native_slave.v  -- Rev 1.2
// GPIO peripheral using PicoRV32's NATIVE memory bus (mem_valid/mem_ready/
// mem_addr/mem_wdata/mem_wstrb/mem_rdata) instead of AXI4-Lite. Supersedes
// gpio_axi_slave.v (now deprecated) per explicit request.
//
// PROTOCOL (PicoRV32 native memory interface, slave side):
//   - mem_valid is asserted by the interconnect/top-level address decoder
//     ONLY when the CPU's current bus cycle falls in GPIO's address region
//     (0x4000_0000-0x4000_0FFF). Same rule as before: this module contains
//     NO global address decoder, it only reacts once selected.
//   - mem_wstrb == 4'b0000 means a READ cycle; any nonzero value is a WRITE,
//     with each bit gating one byte lane of mem_wdata (per PicoRV32 convention).
//   - mem_ready is asserted for exactly one cycle to signal completion; this
//     module follows the classic PicoSoC peripheral idiom (see picorv32's own
//     simpleuart.v for the reference pattern this mirrors): fixed ONE-CYCLE
//     latency from mem_valid to mem_ready, never combinational same-cycle.
//     mem_rdata is valid in the same cycle mem_ready is high.
//   - Reset (`resetn`) is SYNCHRONOUS, matching PicoRV32's own internal
//     convention (picorv32.v itself uses `always @(posedge clk) if (!resetn)`,
//     not an async-reset sensitivity list) -- kept consistent here so the
//     whole native-bus SoC uses one reset style throughout.
//
// Local address map (UNCHANGED from the Rev 1.0/1.1 AXI4-Lite version --
// only the bus protocol changed, not the register map):
//   0x00  GPIO_DATA_OUT  (R/W)  [31:0]  driven onto gpio_out when corresponding
//                                       GPIO_DIR bit = 1
//   0x04  GPIO_DATA_IN   (RO)   [31:0]  synchronized snapshot of gpio_in
//   0x08  GPIO_DIR       (R/W)  [31:0]  1 = pin is output, 0 = pin is input
//   0x0C  GPIO_STATUS    (RO)  [31:0]  bit0 = write_pulse (1-cycle strobe on any
//                                       accepted write to DATA_OUT)
// All other offsets: mem_rdata = 0, mem_ready still asserted (PicoRV32's
// native bus has no error-response channel like AXI's SLVERR -- an unmapped
// access simply reads back 0 and completes normally; LLM-3 should catch bad
// accesses via mem_addr bounds-checking at the interconnect/decoder level,
// not via a bus-level error response, since none exists in this protocol).
// =============================================================================
module gpio_native_slave #(
    parameter GPIO_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  resetn,      // synchronous, active-low (PicoRV32 convention)

    // PicoRV32 native memory bus (slave side)
    input  wire                  mem_valid,   // asserted only while this peripheral is selected
    input  wire                  mem_instr,   // unused here -- GPIO is never an instruction-fetch target;
                                               // passed through for interface completeness only
    output reg                   mem_ready,
    input  wire [11:0]           mem_addr,    // local 12-bit offset only (decoder strips upper bits,
                                               // same rule as the AXI revision -- no global decode here)
    input  wire [31:0]           mem_wdata,
    input  wire [3:0]            mem_wstrb,   // 0000 = read; nonzero = write, bit-per-byte-lane
    output reg  [31:0]           mem_rdata,

    // Peripheral-side pins (unchanged from the AXI version)
    output wire [GPIO_WIDTH-1:0] gpio_out,
    output wire [GPIO_WIDTH-1:0] gpio_oe,
    input  wire [GPIO_WIDTH-1:0] gpio_in
);

    localparam ADDR_DATA_OUT = 12'h000;
    localparam ADDR_DATA_IN  = 12'h004;
    localparam ADDR_DIR      = 12'h008;
    localparam ADDR_STATUS   = 12'h00C;

    reg [31:0] reg_data_out;
    reg [31:0] reg_dir;
    reg        write_pulse;

    assign gpio_out = reg_data_out[GPIO_WIDTH-1:0];
    assign gpio_oe  = reg_dir[GPIO_WIDTH-1:0];

    // 2-FF synchronizer for external input pins (unchanged behavior from AXI version)
    reg [31:0] gpio_in_ff1, gpio_in_sync;
    always @(posedge clk) begin
        if (!resetn) begin
            gpio_in_ff1  <= 32'h0;
            gpio_in_sync <= 32'h0;
        end else begin
            gpio_in_ff1[GPIO_WIDTH-1:0] <= gpio_in;
            gpio_in_sync                <= gpio_in_ff1;
        end
    end

    // Classic PicoSoC peripheral idiom: one-cycle fixed latency, mem_ready
    // pulses exactly once per accepted mem_valid.
    always @(posedge clk) begin
        if (!resetn) begin
            mem_ready    <= 1'b0;
            mem_rdata    <= 32'h0;
            reg_data_out <= 32'h0;
            reg_dir      <= 32'h0;
            write_pulse  <= 1'b0;
        end else begin
            mem_ready   <= 1'b0; // default: only high for the one cycle below
            write_pulse <= 1'b0; // default: 1-cycle strobe, self-clears

            if (mem_valid && !mem_ready) begin
                mem_ready <= 1'b1;

                if (mem_wstrb == 4'b0000) begin
                    // ---- Read ----
                    case (mem_addr)
                        ADDR_DATA_OUT: mem_rdata <= reg_data_out;
                        ADDR_DATA_IN:  mem_rdata <= gpio_in_sync;
                        ADDR_DIR:      mem_rdata <= reg_dir;
                        ADDR_STATUS:   mem_rdata <= {31'h0, write_pulse};
                        default:       mem_rdata <= 32'h0; // unmapped: reads 0, no error channel in this protocol
                    endcase
                end else begin
                    // ---- Write ----
                    case (mem_addr)
                        ADDR_DATA_OUT: begin
                            if (mem_wstrb[0]) reg_data_out[7:0]   <= mem_wdata[7:0];
                            if (mem_wstrb[1]) reg_data_out[15:8]  <= mem_wdata[15:8];
                            if (mem_wstrb[2]) reg_data_out[23:16] <= mem_wdata[23:16];
                            if (mem_wstrb[3]) reg_data_out[31:24] <= mem_wdata[31:24];
                            write_pulse <= 1'b1;
                        end
                        ADDR_DIR: begin
                            if (mem_wstrb[0]) reg_dir[7:0]   <= mem_wdata[7:0];
                            if (mem_wstrb[1]) reg_dir[15:8]  <= mem_wdata[15:8];
                            if (mem_wstrb[2]) reg_dir[23:16] <= mem_wdata[23:16];
                            if (mem_wstrb[3]) reg_dir[31:24] <= mem_wdata[31:24];
                        end
                        default: ; // RO / unmapped: write silently dropped, mem_ready still fires
                    endcase
                end
            end
        end
    end

endmodule
