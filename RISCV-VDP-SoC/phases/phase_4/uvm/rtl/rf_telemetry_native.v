`ifndef RF_TELEMETRY_NATIVE_SLAVE_V
`define RF_TELEMETRY_NATIVE_SLAVE_V

// =============================================================================
// rf_telemetry_native_slave.v
//
// RF telemetry peripheral using PicoRV32 native memory interface.
//
// Local address map:
//   0x00  RF_RSSI       RO   [7:0]   Signed RSSI in 2's complement
//   0x04  RF_LINK_STAT  RO   [31:0]  bit0=link_up
//                                      bit1=link_error
//                                      bit2=carrier_detect
//   0x08  RF_CONTROL    R/W  [0]     rf_enable
//   0x0C  RF_ID         RO   [31:0]  32'h52465430 ("RFT0")
//   0x10  RF_BAND       RO   [31:0]  Band ID (set via BAND_ID parameter)
//                                      0 = 2.4 GHz
//                                      1 = 5   GHz
//                                      2 = 900 MHz
//                                      3 = Sub-1GHz
//
// Native PicoRV32 bus:
//   mem_wstrb == 4'b0000 : READ
//   mem_wstrb != 4'b0000 : WRITE
//
// Unmapped accesses:
//   Read  -> 0
//   Write -> ignored
//   mem_ready still asserted
//
// No global address decoding is performed here.
// The SoC interconnect must select this peripheral and provide
// the local address offset.
// =============================================================================

module rf_telemetry_native_slave #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 32,
    // parameter [31:0] BAND_ID = 32'd0   // 0=2.4GHz 1=5GHz 2=900MHz 3=Sub-1GHz
)(
    input  wire                     clk,
    input  wire                     resetn,

    // ============================================================
    // PicoRV32 native memory interface
    // ============================================================

    input  wire                     mem_valid,
    input  wire                     mem_instr,

    output reg                      mem_ready,

    input  wire [ADDR_WIDTH-1:0]    mem_addr,
    input  wire [DATA_WIDTH-1:0]    mem_wdata,
    input  wire [DATA_WIDTH/8-1:0]  mem_wstrb,

    output reg  [DATA_WIDTH-1:0]    mem_rdata,

    // ============================================================
    // RF telemetry inputs
    // ============================================================

    input  wire [7:0]               rssi_dbm_i,
    input  wire                     link_up_i,
    input  wire                     link_error_i,
    input  wire                     carrier_detect_i,

    // ============================================================
    // RF control output
    // ============================================================

    output wire                     rf_enable_o
);

    // ============================================================
    // Local register map
    // ============================================================

    localparam [ADDR_WIDTH-1:0] ADDR_RSSI =
        12'h000;

    localparam [ADDR_WIDTH-1:0] ADDR_LINKSTAT =
        12'h004;

    localparam [ADDR_WIDTH-1:0] ADDR_CONTROL =
        12'h008;

    localparam [ADDR_WIDTH-1:0] ADDR_ID =
        12'h00C;

    // localparam [ADDR_WIDTH-1:0] ADDR_BAND =
    //     12'h010;

    localparam [31:0] RF_ID_VALUE =
        32'h5246_5430;       // "RFT0"

    // ============================================================
    // RF telemetry synchronizers
    // ============================================================

    reg [7:0] rssi_ff1;
    reg [7:0] rssi_sync;

    reg link_up_ff1;
    reg link_up_sync;

    reg link_error_ff1;
    reg link_error_sync;

    reg carrier_detect_ff1;
    reg carrier_detect_sync;

    always @(posedge clk) begin

        if (!resetn) begin

            rssi_ff1           <= 8'h00;
            rssi_sync          <= 8'h00;

            link_up_ff1        <= 1'b0;
            link_up_sync       <= 1'b0;

            link_error_ff1     <= 1'b0;
            link_error_sync    <= 1'b0;

            carrier_detect_ff1 <= 1'b0;
            carrier_detect_sync<= 1'b0;

        end

        else begin

            rssi_ff1            <= rssi_dbm_i;
            rssi_sync           <= rssi_ff1;

            link_up_ff1         <= link_up_i;
            link_up_sync        <= link_up_ff1;

            link_error_ff1      <= link_error_i;
            link_error_sync     <= link_error_ff1;

            carrier_detect_ff1  <= carrier_detect_i;
            carrier_detect_sync <= carrier_detect_ff1;

        end
    end

    // ============================================================
    // Link status register
    // ============================================================

    wire [31:0] link_status_word;

    assign link_status_word =
        {29'h00000000,
         carrier_detect_sync,
         link_error_sync,
         link_up_sync};

    // ============================================================
    // RF control register
    // ============================================================

    reg reg_rf_enable;

    assign rf_enable_o = reg_rf_enable;

    // ============================================================
    // Native bus transaction
    //
    // One-cycle response latency:
    //
    // Cycle N:
    //     mem_valid = 1
    //
    // Cycle N+1:
    //     mem_ready = 1
    //     mem_rdata = valid read data
    //
    // ============================================================

    always @(posedge clk) begin

        if (!resetn) begin

            mem_ready    <= 1'b0;
            mem_rdata    <= 32'h0000_0000;

            reg_rf_enable <= 1'b0;

        end

        else begin

            // Default: ready is a one-cycle pulse.
            mem_ready <= 1'b0;

            // ----------------------------------------------------
            // Accept native bus transaction
            // ----------------------------------------------------

            if (mem_valid && !mem_ready) begin

                mem_ready <= 1'b1;

                // =================================================
                // READ
                // =================================================

                if (mem_wstrb == 4'b0000) begin

                    case (mem_addr)

                        ADDR_RSSI: begin
                            // RSSI is an 8-bit signed two's-complement
                            // value. Zero extension preserves the raw
                            // byte representation.
                            mem_rdata <= {
                                24'h000000,
                                rssi_sync
                            };
                        end

                        ADDR_LINKSTAT: begin
                            mem_rdata <= link_status_word;
                        end

                        ADDR_CONTROL: begin
                            mem_rdata <= {
                                31'h00000000,
                                reg_rf_enable
                            };
                        end

                        ADDR_ID: begin
                            mem_rdata <= RF_ID_VALUE;
                        end

                        // ADDR_BAND: begin
                        //     mem_rdata <= BAND_ID;
                        // end

                        default: begin
                            mem_rdata <= 32'h0000_0000;
                        end

                    endcase

                end

                // =================================================
                // WRITE
                // =================================================

                else begin

                    case (mem_addr)

                        ADDR_CONTROL: begin

                            // Only byte lane 0 contains the
                            // RF_ENABLE control bit.

                            if (mem_wstrb[0])
                                reg_rf_enable <= mem_wdata[0];

                        end

                        default: begin
                            // RO and unmapped registers:
                            // silently ignore writes.
                        end

                    endcase

                end

            end

        end

    end

endmodule

`endif