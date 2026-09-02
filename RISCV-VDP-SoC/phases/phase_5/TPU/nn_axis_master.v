`timescale 1ns / 1ps

//==============================================================================
// Module      : nn_axis_master
// Project     : RISCV-VDP-SoC
//
// Description :
//   Native-register-to-AXI4-Stream packet generator.
//
//   This module receives seven 64-bit payload values from nn_axi_wrapper and
//   serializes them into one AXI4-Stream packet.
//
// Packet:
//
//       beat 0 : weight0
//       beat 1 : weight1
//       beat 2 : weight2
//       beat 3 : weight3
//       beat 4 : weight4
//       beat 5 : input0
//       beat 6 : input1 + TLAST
//
// AXI4-Stream rule:
//   A beat is transferred only when:
//
//       m_axis_tvalid && m_axis_tready
//
//   The packet index is therefore advanced ONLY on a successful handshake.
//
// Result handling:
//   axis_nn produces two output beats. This module waits for those beats and
//   generates BUSY/DONE status for the MMIO wrapper.
//
//==============================================================================

module nn_axis_master (

    input wire         clk,
    input wire         rst_n,

    //--------------------------------------------------------------------------
    // Command from MMIO wrapper
    //--------------------------------------------------------------------------
    input wire         axis_start,

    input wire [63:0]  weight0,
    input wire [63:0]  weight1,
    input wire [63:0]  weight2,
    input wire [63:0]  weight3,
    input wire [63:0]  weight4,

    input wire [63:0]  input0,
    input wire [63:0]  input1,

    //--------------------------------------------------------------------------
    // AXI4-Stream output toward axis_nn
    //--------------------------------------------------------------------------
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg [63:0]  m_axis_tdata,
    output reg         m_axis_tlast,

    //--------------------------------------------------------------------------
    // Result AXI4-Stream input from axis_nn
    //--------------------------------------------------------------------------
    input wire         s_axis_tvalid,
    output reg         s_axis_tready,
    input wire [63:0]  s_axis_tdata,
    input wire         s_axis_tlast,

    //--------------------------------------------------------------------------
    // Accelerator status
    //--------------------------------------------------------------------------
    output reg         axis_busy,
    output reg         axis_done
);

    //==========================================================================
    // FSM states
    //==========================================================================

    localparam [1:0] ST_IDLE   = 2'd0;
    localparam [1:0] ST_SEND   = 2'd1;
    localparam [1:0] ST_RESULT = 2'd2;
    localparam [1:0] ST_DONE   = 2'd3;

    reg [1:0] state_reg;
    reg [2:0] beat_reg;

    //==========================================================================
    // FSM
    //==========================================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state_reg <= ST_IDLE;
            beat_reg  <= 3'd0;

            axis_busy <= 1'b0;
            axis_done <= 1'b0;

        end

        else begin

            // DONE is a one-clock pulse.
            axis_done <= 1'b0;

            case (state_reg)

                //================================================================
                // IDLE
                //================================================================

                ST_IDLE:
                    begin

                        axis_busy <= 1'b0;
                        beat_reg  <= 3'd0;

                        if (axis_start) begin

                            axis_busy <= 1'b1;
                            state_reg <= ST_SEND;
                            beat_reg  <= 3'd0;

                        end
                    end

                //================================================================
                // SEND
                //
                // Keep TVALID asserted until TREADY acknowledges the beat.
                //================================================================

                ST_SEND:
                    begin

                        axis_busy <= 1'b1;

                        if (m_axis_tvalid && m_axis_tready) begin

                            if (beat_reg == 3'd6) begin

                                // Seven input beats have now been accepted.
                                beat_reg  <= 3'd0;
                                state_reg <= ST_RESULT;

                            end

                            else begin

                                beat_reg <= beat_reg + 3'd1;

                            end
                        end
                    end

                //================================================================
                // RESULT
                //
                // Wait for the two output words from axis_nn.
                //================================================================

                ST_RESULT:
                    begin

                        axis_busy <= 1'b1;

                        if (s_axis_tvalid && s_axis_tready) begin

                            // TLAST marks the second/final result beat.
                            if (s_axis_tlast) begin

                                state_reg <= ST_DONE;

                            end
                        end
                    end

                //================================================================
                // DONE
                //================================================================

                ST_DONE:
                    begin

                        axis_busy <= 1'b0;
                        axis_done <= 1'b1;

                        state_reg <= ST_IDLE;

                    end

                default:
                    begin

                        state_reg <= ST_IDLE;
                        beat_reg  <= 3'd0;
                        axis_busy <= 1'b0;

                    end

            endcase
        end
    end

    //==========================================================================
    // AXI4-Stream input packet generation
    //==========================================================================

    always @(*) begin

        // Defaults
        m_axis_tvalid = 1'b0;
        m_axis_tdata  = 64'd0;
        m_axis_tlast  = 1'b0;

        if (state_reg == ST_SEND) begin

            m_axis_tvalid = 1'b1;

            case (beat_reg)

                3'd0:
                    m_axis_tdata = weight0;

                3'd1:
                    m_axis_tdata = weight1;

                3'd2:
                    m_axis_tdata = weight2;

                3'd3:
                    m_axis_tdata = weight3;

                3'd4:
                    m_axis_tdata = weight4;

                3'd5:
                    m_axis_tdata = input0;

                3'd6:
                    begin
                        m_axis_tdata = input1;
                        m_axis_tlast = 1'b1;
                    end

                default:
                    m_axis_tdata = 64'd0;

            endcase
        end
    end

    //==========================================================================
    // AXI4-Stream result acceptance
    //
    // The result path is deliberately always ready while the accelerator is
    // waiting for results. This prevents the axis_nn S2MM FIFO from stalling.
    //==========================================================================

    always @(*) begin

        s_axis_tready = 1'b0;

        if (state_reg == ST_RESULT)
            s_axis_tready = 1'b1;

    end

endmodule