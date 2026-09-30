`timescale 1ns / 1ps

`ifndef NN_AXIS_MASTER_V
`define NN_AXIS_MASTER_V

//==============================================================================
// Module      : nn_axis_master
// Project     : RISCV-VDP-SoC
//
// Description :
//   Native-register-to-AXI4-Stream packet generator and result collector.
//
//   This module receives seven 64-bit payload values from nn_axi_wrapper and
//   serializes them into one AXI4-Stream packet:
//
//       beat 0 : weight0
//       beat 1 : weight1
//       beat 2 : weight2
//       beat 3 : weight3
//       beat 4 : weight4
//       beat 5 : input0
//       beat 6 : input1 + TLAST
//
//   After the seven input beats have been accepted by axis_nn, this module
//   switches to the result phase and accepts exactly two 64-bit result beats:
//
//       result beat 0 : result0
//       result beat 1 : result1 + TLAST
//
// AXI4-Stream handshake rule:
//
//       transfer = TVALID && TREADY
//
//   Therefore:
//
//       - TX beat counter advances only after a successful TX handshake.
//       - RX result counter advances only after a successful RX handshake.
//       - Result data is captured only on a successful RX handshake.
//
// Status:
//
//       axis_busy = 1 while an accelerator transaction is in progress.
//       axis_done = one-clock pulse after both result beats are captured.
//
//==============================================================================

module nn_axis_master (

    input wire         clk,
    input wire         rst_n,

    //----------------------------------------------------------------------
    // Command from MMIO wrapper
    //----------------------------------------------------------------------

    input wire         axis_start,

    input wire [63:0]  weight0,
    input wire [63:0]  weight1,
    input wire [63:0]  weight2,
    input wire [63:0]  weight3,
    input wire [63:0]  weight4,

    input wire [63:0]  input0,
    input wire [63:0]  input1,

    //----------------------------------------------------------------------
    // AXI4-Stream output toward axis_nn
    //----------------------------------------------------------------------

    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg [63:0]  m_axis_tdata,
    output reg         m_axis_tlast,

    //----------------------------------------------------------------------
    // Result AXI4-Stream input from axis_nn
    //----------------------------------------------------------------------

    input  wire        s_axis_tvalid,
    output reg         s_axis_tready,
    input  wire [63:0] s_axis_tdata,
    input  wire        s_axis_tlast,

    //----------------------------------------------------------------------
    // Accelerator status
    //----------------------------------------------------------------------

    output reg         axis_busy,
    output reg         axis_done,

    //----------------------------------------------------------------------
    // Captured accelerator results
    //
    // result0 = first result AXI4-Stream beat
    // result1 = second/final result AXI4-Stream beat
    //----------------------------------------------------------------------

    output reg [63:0] result0,
    output reg [63:0] result1

);

    //==========================================================================
    // FSM states
    //==========================================================================

    localparam [1:0] ST_IDLE   = 2'd0;
    localparam [1:0] ST_SEND   = 2'd1;
    localparam [1:0] ST_RESULT = 2'd2;
    localparam [1:0] ST_DONE   = 2'd3;

    reg [1:0] state_reg;

    //--------------------------------------------------------------------------
    // TX packet beat counter
    //
    // 0 = weight0
    // 1 = weight1
    // 2 = weight2
    // 3 = weight3
    // 4 = weight4
    // 5 = input0
    // 6 = input1
    //--------------------------------------------------------------------------

    reg [2:0] beat_reg;

    //--------------------------------------------------------------------------
    // RX result beat counter
    //
    // 0 = waiting for result0
    // 1 = waiting for result1
    //
    // A two-beat result packet is part of the accelerator interface contract.
    //--------------------------------------------------------------------------

    reg       result_beat_reg;

    //==========================================================================
    // Main control FSM
    //==========================================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            //------------------------------------------------------------------
            // Reset state
            //------------------------------------------------------------------

            state_reg      <= ST_IDLE;
            beat_reg       <= 3'd0;
            result_beat_reg <= 1'b0;

            axis_busy      <= 1'b0;
            axis_done      <= 1'b0;

            //------------------------------------------------------------------
            // Clear captured results.
            //
            // This is important because result0/result1 are actual registered
            // outputs consumed by nn_axi_wrapper through MMIO reads.
            //------------------------------------------------------------------

            result0        <= 64'd0;
            result1        <= 64'd0;

        end
        else begin

            //------------------------------------------------------------------
            // DONE is a one-clock pulse.
            //
            // It is asserted explicitly in ST_DONE below and automatically
            // cleared on the following clock.
            //------------------------------------------------------------------

            axis_done <= 1'b0;

            case (state_reg)

                //================================================================
                // IDLE
                //================================================================

                ST_IDLE:
                    begin

                        axis_busy       <= 1'b0;
                        beat_reg        <= 3'd0;
                        result_beat_reg <= 1'b0;

                        //----------------------------------------------------------------
                        // Start a new accelerator transaction.
                        //----------------------------------------------------------------

                        if (axis_start) begin

                            axis_busy       <= 1'b1;
                            state_reg       <= ST_SEND;

                            beat_reg        <= 3'd0;
                            result_beat_reg <= 1'b0;

                            //----------------------------------------------------------------
                            // Clear previous results when a new transaction starts.
                            //
                            // This prevents stale result data from being mistaken
                            // for the result of the current transaction.
                            //----------------------------------------------------------------

                            result0         <= 64'd0;
                            result1         <= 64'd0;

                        end

                    end


                //================================================================
                // SEND
                //
                // Serialize the seven 64-bit values into AXI4-Stream.
                //
                // The beat counter advances ONLY when:
                //
                //     m_axis_tvalid && m_axis_tready
                //
                // This is required by the AXI4-Stream protocol.
                //================================================================

                ST_SEND:
                    begin

                        axis_busy <= 1'b1;

                        if (m_axis_tvalid && m_axis_tready) begin

                            //----------------------------------------------------------------
                            // Last input beat accepted.
                            //----------------------------------------------------------------

                            if (beat_reg == 3'd6) begin

                                beat_reg        <= 3'd0;
                                result_beat_reg <= 1'b0;

                                state_reg       <= ST_RESULT;

                            end
                            else begin

                                beat_reg <= beat_reg + 3'd1;

                            end

                        end

                    end


                //================================================================
                // RESULT
                //
                // Accept exactly two result beats from axis_nn.
                //
                // First handshake:
                //
                //     result0 <= s_axis_tdata
                //
                // Second handshake:
                //
                //     result1 <= s_axis_tdata
                //
                // After result1 is captured, transition to ST_DONE.
                //
                // s_axis_tlast is expected on the second beat and is therefore
                // naturally associated with result1.
                //================================================================

                ST_RESULT:
                    begin

                        axis_busy <= 1'b1;

                        //----------------------------------------------------------------
                        // Result data is captured ONLY on a valid/ready handshake.
                        //----------------------------------------------------------------

                        if (s_axis_tvalid && s_axis_tready) begin

                            if (result_beat_reg == 1'b0) begin

                                //------------------------------------------------------------
                                // First result beat.
                                //------------------------------------------------------------

                                result0         <= s_axis_tdata;
                                result_beat_reg <= 1'b1;

                            end
                            else begin

                                //------------------------------------------------------------
                                // Second/final result beat.
                                //
                                // Capture result1 regardless of the exact TLAST timing
                                // because the accelerator contract defines two result
                                // beats. TLAST is still present on the AXI interface and
                                // should be asserted by axis_nn for this beat.
                                //------------------------------------------------------------

                                result1         <= s_axis_tdata;

                                result_beat_reg <= 1'b0;
                                state_reg       <= ST_DONE;

                            end

                        end

                    end


                //================================================================
                // DONE
                //
                // Results have already been captured in the preceding clock.
                //
                // Generate a one-clock completion pulse.
                //================================================================

                ST_DONE:
                    begin

                        axis_busy <= 1'b0;
                        axis_done <= 1'b1;

                        state_reg <= ST_IDLE;

                    end


                //================================================================
                // Defensive recovery
                //================================================================

                default:
                    begin

                        state_reg       <= ST_IDLE;
                        beat_reg        <= 3'd0;
                        result_beat_reg <= 1'b0;

                        axis_busy       <= 1'b0;
                        axis_done       <= 1'b0;

                    end

            endcase

        end

    end


    //==========================================================================
    // AXI4-Stream input packet generation
    //
    // This is the MASTER transmit side.
    //
    // TVALID remains asserted for the entire ST_SEND state. TDATA is selected
    // from the current beat counter. The counter itself is changed only by the
    // sequential FSM after a valid/ready handshake.
    //==========================================================================

    always @(*) begin

        //----------------------------------------------------------------------
        // Safe defaults
        //----------------------------------------------------------------------

        m_axis_tvalid = 1'b0;
        m_axis_tdata  = 64'd0;
        m_axis_tlast  = 1'b0;

        //----------------------------------------------------------------------
        // Seven-beat packet is presented during ST_SEND.
        //----------------------------------------------------------------------

        if (state_reg == ST_SEND) begin

            m_axis_tvalid = 1'b1;

            case (beat_reg)

                3'd0:
                    begin
                        m_axis_tdata = weight0;
                    end

                3'd1:
                    begin
                        m_axis_tdata = weight1;
                    end

                3'd2:
                    begin
                        m_axis_tdata = weight2;
                    end

                3'd3:
                    begin
                        m_axis_tdata = weight3;
                    end

                3'd4:
                    begin
                        m_axis_tdata = weight4;
                    end

                3'd5:
                    begin
                        m_axis_tdata = input0;
                    end

                3'd6:
                    begin
                        m_axis_tdata = input1;

                        //----------------------------------------------------------
                        // Last input beat terminates the seven-beat packet.
                        //----------------------------------------------------------

                        m_axis_tlast = 1'b1;
                    end

                default:
                    begin
                        m_axis_tdata = 64'd0;
                        m_axis_tlast = 1'b0;
                    end

            endcase

        end

    end


    //==========================================================================
    // AXI4-Stream result acceptance
    //
    // The result collector asserts TREADY throughout ST_RESULT.
    //
    // This allows axis_nn to transfer its result packet without being blocked
    // by this module.
    //
    // Actual capture occurs in the sequential FSM only when:
    //
    //     s_axis_tvalid && s_axis_tready
    //==========================================================================

    always @(*) begin

        s_axis_tready = 1'b0;

        if (state_reg == ST_RESULT)
            s_axis_tready = 1'b1;

    end

endmodule

`endif