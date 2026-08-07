`ifndef CONTROL_STATUS_NATIVE_SLAVE_V
`define CONTROL_STATUS_NATIVE_SLAVE_V

// =============================================================================
// control_status_native_slave.v
// Global SoC control/status register block using PicoRV32 native memory bus.
//
// Local address map:
//   0x00  SOC_ID       (RO)  32'h56445030 ("VDP0")
//   0x04  SOC_CTRL     (write) bit0 = soft-reset request
//   0x08  SOC_STATUS   (RO)  aggregated peripheral status
//
// Native PicoRV32 bus:
//   mem_wstrb == 4'b0000 : READ
//   mem_wstrb != 4'b0000 : WRITE
//
// No global address decoding is performed here.
// The SoC interconnect must assert mem_valid only when this block is selected.
// =============================================================================

module control_status_native_slave (

    input  wire        clk,
    input  wire        resetn,

    // ------------------------------------------------------------------------
    // PicoRV32 native memory interface
    // ------------------------------------------------------------------------
    input  wire        mem_valid,
    input  wire        mem_instr,

    output reg         mem_ready,

    input  wire [11:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,

    output reg  [31:0] mem_rdata,

    // ------------------------------------------------------------------------
    // Aggregated status inputs
    // ------------------------------------------------------------------------
    input  wire        gpio_irq_i,
    input  wire        sensor_alarm_i,
    input  wire        rf_link_up_i,
    input  wire        vdp_frame_flag_i,

    // ------------------------------------------------------------------------
    // Control output
    // ------------------------------------------------------------------------
    output reg         soft_reset_o
);

    // ========================================================================
    // Local register addresses
    // ========================================================================

    localparam ADDR_ID     = 12'h000;
    localparam ADDR_CTRL   = 12'h004;
    localparam ADDR_STATUS = 12'h008;

    localparam [31:0] SOC_ID_VALUE = 32'h5644_5030; // "VDP0"

    // ========================================================================
    // Status word
    //
    // bit 0 = gpio_irq
    // bit 1 = sensor_alarm
    // bit 2 = rf_link_up
    // bit 3 = vdp_frame_flag
    // ========================================================================

    wire [31:0] status_word;

    assign status_word = {
        28'h0,
        vdp_frame_flag_i,
        rf_link_up_i,
        sensor_alarm_i,
        gpio_irq_i
    };

    // ========================================================================
    // Native bus transaction handling
    //
    // One-cycle response:
    //
    // Cycle N:
    //   mem_valid = 1
    //
    // Cycle N+1:
    //   mem_ready = 1
    //   mem_rdata = valid read data
    //
    // Writes are committed when the transaction is accepted.
    // ========================================================================

    always @(posedge clk) begin

        if (!resetn) begin

            mem_ready   <= 1'b0;
            mem_rdata   <= 32'h0000_0000;
            soft_reset_o <= 1'b0;

        end else begin

            // Defaults
            mem_ready    <= 1'b0;
            soft_reset_o <= 1'b0;

            // ---------------------------------------------------------------
            // Accept native-bus transaction
            // ---------------------------------------------------------------

            if (mem_valid && !mem_ready) begin

                // Complete transaction
                mem_ready <= 1'b1;

                // -----------------------------------------------------------
                // READ
                // -----------------------------------------------------------

                if (mem_wstrb == 4'b0000) begin

                    case (mem_addr)

                        ADDR_ID: begin
                            mem_rdata <= SOC_ID_VALUE;
                        end

                        ADDR_CTRL: begin
                            // Self-clearing control register.
                            // Always reads back zero.
                            mem_rdata <= 32'h0000_0000;
                        end

                        ADDR_STATUS: begin
                            mem_rdata <= status_word;
                        end

                        default: begin
                            // Unmapped read
                            mem_rdata <= 32'h0000_0000;
                        end

                    endcase

                end

                // -----------------------------------------------------------
                // WRITE
                // -----------------------------------------------------------

                else begin

                    case (mem_addr)

                        ADDR_CTRL: begin

                            // Only byte lane 0 / bit 0 is meaningful.
                            //
                            // A write of:
                            //   0x00000001
                            //
                            // generates a one-cycle soft-reset pulse.

                            if (mem_wstrb[0] &&
                                mem_wdata[0]) begin

                                soft_reset_o <= 1'b1;

                            end

                        end

                        default: begin
                            // RO/unmapped writes are silently ignored.
                        end

                    endcase

                end
            end
        end
    end

endmodule

`endif