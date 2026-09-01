`timescale 1ns / 1ps

// =============================================================================
// nn_axi_wrapper.sv
//
// RISC-V native-bus to AXI4-Lite + AXI4-Stream NN/TPU wrapper
//
// PURPOSE
// -------
// This module provides a wrapper around the existing AXI4-Stream accelerator
// "axis_nn".
//
// The wrapper exposes TWO control/access paths:
//
//   1. PicoRV32 native memory-mapped interface
//      - Used by the RISC-V CPU inside the SoC.
//      - Address window:
//          0x0001_4000 - 0x0001_4FFF
//
//   2. AXI4-Lite slave interface
//      - Used by an AXI master such as a Xilinx MicroBlaze, PS, test master,
//        or another AXI-connected component.
//      - Uses Xilinx-style AXI naming intentionally.
//
// The accelerator itself communicates through AXI4-Stream:
//
//      Input :  s_axis_tdata / tvalid / tready / tlast
//      Output:  m_axis_tdata / tvalid / tready / tlast
//
// IMPORTANT REGISTER-OWNERSHIP RULE
// ---------------------------------
// All writable state registers in this module have ONE sequential writer.
//
// In particular:
//
//      control_reg
//      input_data_reg
//
// are NEVER assigned from the combinational PicoRV32 interface logic.
//
// Instead:
//
//      PicoRV32 write request ----\
//                                  >---- single clocked write process
//      AXI4-Lite write request ---/
//
// This avoids multiple-driver synthesis errors and makes the RTL clean,
// deterministic, and synthesizable.
//
// =============================================================================
//
// REGISTER MAP
// =============================================================================
//
// Offset       Name               Access       Description
// -----------------------------------------------------------------------------
// 0x00         CONTROL            R/W          bit 0 = ENABLE
//                                               bit 1 = START command
//
//                                              START is treated as a pulse.
//                                              It is NOT stored permanently.
//
// 0x04         STATUS             R            bit 0 = output valid
//                                               bit 1 = output last
//                                               bit 2 = input valid
//                                               bit 3 = input ready
//
// 0x08         VERSION            R            32'h0001_0000
//
// 0x0C         INPUT_DATA_LO      R/W          input_data_reg[31:0]
//
// 0x10         INPUT_DATA_HI      R/W          input_data_reg[63:32]
//
// 0x14         OUTPUT_DATA_LO     R            output_data_reg[31:0]
//
// 0x18         OUTPUT_DATA_HI     R            output_data_reg[63:32]
//
// =============================================================================
//
// ADDRESS MAP
// =============================================================================
//
// SoC address:
//
//      0x0001_4000 + local register offset
//
// Example:
//
//      CPU writes 0x0000_0001 to
//
//          0x0001_4000
//
//      -> CONTROL.ENABLE = 1
//
// CPU writes 0x0000_0002 to
//
//          0x0001_4000
//
//      -> START command is generated.
//
// CPU writes:
//
//      0x1234_5678 -> 0x0001_400C
//      0x9ABC_DEF0 -> 0x0001_4010
//
//      -> 64-bit input data becomes:
//
//          input_data_reg = 64'h9ABC_DEF0_1234_5678
//
// =============================================================================
//
// AXI4-LITE ADDRESSING
// =============================================================================
//
// C_S_AXI_ADDR_WIDTH = 6 gives:
//
//      0x00 CONTROL
//      0x04 STATUS
//      0x08 VERSION
//      0x0C INPUT_DATA_LO
//      0x10 INPUT_DATA_HI
//      0x14 OUTPUT_DATA_LO
//      0x18 OUTPUT_DATA_HI
//
// Since the interface is 32-bit:
//
//      s_axi_awaddr[5:2]
//
// selects the 32-bit register.
//
// =============================================================================

module nn_axi_wrapper #(

    // -------------------------------------------------------------------------
    // Xilinx-style AXI4-Lite parameters
    // -------------------------------------------------------------------------
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6

)(

    // =========================================================================
    // CLOCK / RESET
    // =========================================================================

    input wire aclk,
    input wire aresetn,


    // =========================================================================
    // NATIVE PICORV32 / SOC INTERFACE
    // =========================================================================
    //
    // This interface connects directly to soc_mem_interconnect.
    //
    // The interconnect decodes:
    //
    //      0x0001_4000 - 0x0001_4FFF
    //
    // and converts the system address into nn_addr[11:0].
    //
    // =========================================================================

    input  wire        nn_valid,
    input  wire        nn_write,
    input  wire [11:0] nn_addr,
    input  wire [31:0] nn_wdata,
    input  wire [3:0]  nn_strb,

    output reg         nn_ready,
    output reg  [31:0] nn_rdata,


    // =========================================================================
    // AXI4-LITE SLAVE INTERFACE
    // =========================================================================
    //
    // Xilinx AXI naming is intentionally retained:
    //
    //      s_axi_awaddr
    //      s_axi_awvalid
    //      s_axi_awready
    //
    //      s_axi_wdata
    //      s_axi_wstrb
    //      s_axi_wvalid
    //      s_axi_wready
    //
    //      s_axi_bresp
    //      s_axi_bvalid
    //      s_axi_bready
    //
    //      s_axi_araddr
    //      s_axi_arvalid
    //      s_axi_arready
    //
    //      s_axi_rdata
    //      s_axi_rresp
    //      s_axi_rvalid
    //      s_axi_rready
    //
    // =========================================================================

    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                          s_axi_awvalid,
    output wire                          s_axi_awready,

    input  wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                          s_axi_wvalid,
    output wire                          s_axi_wready,

    output wire [1:0]                    s_axi_bresp,
    output wire                          s_axi_bvalid,
    input  wire                          s_axi_bready,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                          s_axi_arvalid,
    output wire                          s_axi_arready,

    output wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output wire [1:0]                    s_axi_rresp,
    output wire                          s_axi_rvalid,
    input  wire                          s_axi_rready,


    // =========================================================================
    // AXI4-STREAM INPUT
    // =========================================================================
    //
    // These are the external Xilinx-style AXI4-Stream ports.
    //
    // In this wrapper implementation the CPU/AXI-Lite register path generates
    // the internal accelerator input transaction from input_data_reg.
    //
    // The external stream interface is retained as part of the wrapper
    // interface and can be connected at the SoC/block-design level.
    //
    // =========================================================================

    input  wire [63:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,


    // =========================================================================
    // AXI4-STREAM OUTPUT
    // =========================================================================

    output wire [63:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast

);


    // =========================================================================
    // REGISTER STORAGE
    // =========================================================================
    //
    // IMPORTANT:
    //
    // These registers are actual hardware state.
    //
    // They MUST NOT be assigned from always @(*) logic.
    //
    // There is exactly ONE sequential process below responsible for modifying
    // control_reg and input_data_reg.
    // =========================================================================

    reg [31:0] control_reg;

    reg [63:0] input_data_reg;

    // -------------------------------------------------------------------------
    // input_valid_reg
    //
    // Indicates that input_data_reg is waiting to be accepted by axis_nn.
    //
    // This is generated when a START command is received.
    // -------------------------------------------------------------------------

    reg input_valid_reg;

    // -------------------------------------------------------------------------
    // input_last_reg
    //
    // Indicates TLAST for the generated input transaction.
    //
    // For the current single-word transaction model, TLAST is always asserted.
    // -------------------------------------------------------------------------

    reg input_last_reg;

    // -------------------------------------------------------------------------
    // Captured accelerator output
    // -------------------------------------------------------------------------

    reg [63:0] output_data_reg;

    reg output_valid_reg;

    reg output_last_reg;


    // =========================================================================
    // AXI4-LITE INTERNAL REGISTERS
    // =========================================================================

    reg [31:0] axi_rdata_reg;

    reg        axi_rvalid_reg;

    reg        axi_bvalid_reg;

    reg        awready_reg;

    reg        wready_reg;

    reg        arready_reg;


    // =========================================================================
    // AXI4-LITE OUTPUT ASSIGNMENTS
    // =========================================================================

    assign s_axi_awready = awready_reg;

    assign s_axi_wready  = wready_reg;

    assign s_axi_bvalid  = axi_bvalid_reg;

    // 2'b00 = AXI OKAY response
    assign s_axi_bresp   = 2'b00;

    assign s_axi_arready = arready_reg;

    assign s_axi_rdata   = axi_rdata_reg;

    assign s_axi_rvalid  = axi_rvalid_reg;

    // 2'b00 = AXI OKAY response
    assign s_axi_rresp   = 2'b00;


    // =========================================================================
    // INTERNAL WRITE REQUEST SIGNALS
    // =========================================================================
    //
    // These signals do NOT modify registers.
    //
    // They only describe whether a write request is currently being presented
    // by each interface.
    //
    // The actual register update occurs later in the single clocked register
    // write process.
    // =========================================================================

    wire axi_write_fire;

    wire native_write_fire;

    assign axi_write_fire =
        s_axi_awvalid &&
        s_axi_wvalid &&
        awready_reg &&
        wready_reg;

    assign native_write_fire =
        nn_valid &&
        nn_write;


    // =========================================================================
    // AXI4-LITE WRITE CHANNEL CONTROL
    // =========================================================================
    //
    // This process ONLY manages the AXI protocol state:
    //
    //      AWREADY
    //      WREADY
    //      BVALID
    //
    // It does NOT directly modify control_reg or input_data_reg.
    //
    // This separation is important because the register storage is handled
    // by the dedicated register-write process later in this module.
    // =========================================================================

    always @(posedge aclk) begin

        if (!aresetn) begin

            axi_bvalid_reg <= 1'b0;

            awready_reg    <= 1'b1;

            wready_reg     <= 1'b1;

        end
        else begin

            // -----------------------------------------------------------------
            // AXI write request accepted
            // -----------------------------------------------------------------
            //
            // Both address and data must be valid in this simple AXI-Lite
            // implementation.
            //
            // Once accepted, AWREADY and WREADY are deasserted until the
            // master accepts the write response.
            // -----------------------------------------------------------------

            if (axi_write_fire) begin

                axi_bvalid_reg <= 1'b1;

                awready_reg    <= 1'b0;

                wready_reg     <= 1'b0;

            end


            // -----------------------------------------------------------------
            // AXI write response accepted
            // -----------------------------------------------------------------

            if (axi_bvalid_reg && s_axi_bready) begin

                axi_bvalid_reg <= 1'b0;

                awready_reg    <= 1'b1;

                wready_reg     <= 1'b1;

            end

        end

    end


    // =========================================================================
    // AXI4-LITE READ CHANNEL
    // =========================================================================
    //
    // AXI reads are handled independently from AXI writes.
    //
    // Register values are read from the current register state.
    //
    // =========================================================================

    always @(posedge aclk) begin

        if (!aresetn) begin

            axi_rdata_reg  <= 32'd0;

            axi_rvalid_reg <= 1'b0;

            arready_reg    <= 1'b1;

        end
        else begin

            // -----------------------------------------------------------------
            // Accept AXI read address
            // -----------------------------------------------------------------

            if (s_axi_arvalid && arready_reg) begin

                case (s_axi_araddr[5:2])

                    // ---------------------------------------------------------
                    // CONTROL
                    // ---------------------------------------------------------
                    4'h0:
                        axi_rdata_reg <= control_reg;


                    // ---------------------------------------------------------
                    // STATUS
                    // ---------------------------------------------------------
                    //
                    // bit 0 = output valid
                    // bit 1 = output last
                    // bit 2 = input valid
                    // bit 3 = input ready
                    //
                    // ---------------------------------------------------------
                    4'h1:
                        axi_rdata_reg <= {

                            28'd0,

                           // nn_s_axis_tready,

                            input_valid_reg,

                            output_last_reg,

                            output_valid_reg

                        };


                    // ---------------------------------------------------------
                    // VERSION
                    // ---------------------------------------------------------
                    4'h2:
                        axi_rdata_reg <= 32'h0001_0000;


                    // ---------------------------------------------------------
                    // INPUT DATA LOW
                    // ---------------------------------------------------------
                    4'h3:
                        axi_rdata_reg <= input_data_reg[31:0];


                    // ---------------------------------------------------------
                    // INPUT DATA HIGH
                    // ---------------------------------------------------------
                    4'h4:
                        axi_rdata_reg <= input_data_reg[63:32];


                    // ---------------------------------------------------------
                    // OUTPUT DATA LOW
                    // ---------------------------------------------------------
                    4'h5:
                        axi_rdata_reg <= output_data_reg[31:0];


                    // ---------------------------------------------------------
                    // OUTPUT DATA HIGH
                    // ---------------------------------------------------------
                    4'h6:
                        axi_rdata_reg <= output_data_reg[63:32];


                    // ---------------------------------------------------------
                    // Undefined register
                    // ---------------------------------------------------------
                    default:
                        axi_rdata_reg <= 32'd0;

                endcase


                // Data is now available to the AXI master.
                axi_rvalid_reg <= 1'b1;

                // Prevent another read from being accepted until the current
                // read response has been consumed.
                arready_reg <= 1'b0;

            end


            // -----------------------------------------------------------------
            // AXI read response accepted
            // -----------------------------------------------------------------

            if (axi_rvalid_reg && s_axi_rready) begin

                axi_rvalid_reg <= 1'b0;

                arready_reg    <= 1'b1;

            end

        end

    end


    // =========================================================================
    // SINGLE REGISTER-WRITE PROCESS
    // =========================================================================
    //
    // THIS IS THE IMPORTANT FIX.
    //
    // control_reg and input_data_reg are written ONLY HERE.
    //
    // Both interfaces can request a write:
    //
    //      AXI4-Lite
    //          OR
    //      PicoRV32 native bus
    //
    // but there is only ONE physical writer for the registers.
    //
    // -------------------------------------------------------------------------
    // PRIORITY
    // -------------------------------------------------------------------------
    //
    // If AXI4-Lite and PicoRV32 happen to request a write in the exact same
    // clock cycle, AXI4-Lite is given priority.
    //
    // In the intended SoC architecture this normally does not matter because
    // the PicoRV32 native bus and AXI master are not expected to simultaneously
    // control the same accelerator register.
    //
    // =========================================================================

    always @(posedge aclk) begin

        if (!aresetn) begin

            control_reg    <= 32'd0;

            input_data_reg <= 64'd0;

        end
        else begin

            // =================================================================
            // AXI4-Lite WRITE HAS PRIORITY
            // =================================================================

            if (axi_write_fire) begin

                case (s_axi_awaddr[5:2])

                    // ---------------------------------------------------------
                    // CONTROL REGISTER
                    // ---------------------------------------------------------
                    //
                    // bit 0 = ENABLE
                    //
                    // bit 1 = START command
                    //
                    // IMPORTANT:
                    //
                    // bit 1 is intentionally NOT stored in control_reg.
                    // Instead it is converted into a one-cycle start request
                    // in the input-control process.
                    //
                    // Therefore reading CONTROL will return:
                    //
                    //      bit 0 = current enable state
                    //      bit 1 = 0
                    //
                    // This prevents START from remaining permanently asserted.
                    // ---------------------------------------------------------

                    4'h0: begin

                        if (s_axi_wstrb[0]) begin

                            control_reg[0] <= s_axi_wdata[0];

                            // Bit 1 is a command and is handled separately.
                            // All other control bits are currently reserved.
                            control_reg[31:1] <= 31'd0;

                        end

                    end


                    // ---------------------------------------------------------
                    // INPUT DATA LOW
                    // ---------------------------------------------------------

                    4'h3: begin

                        if (s_axi_wstrb[0])
                            input_data_reg[7:0] <= s_axi_wdata[7:0];

                        if (s_axi_wstrb[1])
                            input_data_reg[15:8] <= s_axi_wdata[15:8];

                        if (s_axi_wstrb[2])
                            input_data_reg[23:16] <= s_axi_wdata[23:16];

                        if (s_axi_wstrb[3])
                            input_data_reg[31:24] <= s_axi_wdata[31:24];

                    end


                    // ---------------------------------------------------------
                    // INPUT DATA HIGH
                    // ---------------------------------------------------------

                    4'h4: begin

                        if (s_axi_wstrb[0])
                            input_data_reg[39:32] <= s_axi_wdata[7:0];

                        if (s_axi_wstrb[1])
                            input_data_reg[47:40] <= s_axi_wdata[15:8];

                        if (s_axi_wstrb[2])
                            input_data_reg[55:48] <= s_axi_wdata[23:16];

                        if (s_axi_wstrb[3])
                            input_data_reg[63:56] <= s_axi_wdata[31:24];

                    end


                    // ---------------------------------------------------------
                    // Other registers are read-only or undefined.
                    // ---------------------------------------------------------

                    default: begin

                    end

                endcase

            end


            // =================================================================
            // NATIVE PICORV32 WRITE
            // =================================================================
            //
            // This section is executed only when there was NOT an AXI write.
            //
            // Again, registers are written here -- not in always @(*).
            // =================================================================

            else if (native_write_fire) begin

                case (nn_addr)

                    // ---------------------------------------------------------
                    // CONTROL
                    // ---------------------------------------------------------

                    12'h000: begin

                        if (nn_strb[0]) begin

                            // ENABLE is a persistent state bit.
                            control_reg[0] <= nn_wdata[0];

                            // START is NOT stored.
                            // It is handled by start-request logic below.

                            control_reg[31:1] <= 31'd0;

                        end

                    end


                    // ---------------------------------------------------------
                    // INPUT DATA LOW
                    // ---------------------------------------------------------

                    12'h00C: begin

                        if (nn_strb[0])
                            input_data_reg[7:0] <= nn_wdata[7:0];

                        if (nn_strb[1])
                            input_data_reg[15:8] <= nn_wdata[15:8];

                        if (nn_strb[2])
                            input_data_reg[23:16] <= nn_wdata[23:16];

                        if (nn_strb[3])
                            input_data_reg[31:24] <= nn_wdata[31:24];

                    end


                    // ---------------------------------------------------------
                    // INPUT DATA HIGH
                    // ---------------------------------------------------------

                    12'h010: begin

                        if (nn_strb[0])
                            input_data_reg[39:32] <= nn_wdata[7:0];

                        if (nn_strb[1])
                            input_data_reg[47:40] <= nn_wdata[15:8];

                        if (nn_strb[2])
                            input_data_reg[55:48] <= nn_wdata[23:16];

                        if (nn_strb[3])
                            input_data_reg[63:56] <= nn_wdata[31:24];

                    end


                    // ---------------------------------------------------------
                    // Other registers are read-only or undefined.
                    // ---------------------------------------------------------

                    default: begin

                    end

                endcase

            end

        end

    end


    // =========================================================================
    // NATIVE PICORV32 READ / READY LOGIC
    // =========================================================================
    //
    // IMPORTANT:
    //
    // This process ONLY generates:
    //
    //      nn_ready
    //      nn_rdata
    //
    // It does NOT modify control_reg or input_data_reg.
    //
    // Therefore the combinational read interface cannot create multiple
    // register drivers.
    // =========================================================================

    always @(*) begin

        // ---------------------------------------------------------------------
        // Default response
        // ---------------------------------------------------------------------

        nn_ready = 1'b0;

        nn_rdata = 32'd0;


        if (nn_valid) begin

            case (nn_addr)

                // =============================================================
                // CONTROL
                // =============================================================

                12'h000: begin

                    nn_ready = 1'b1;

                    if (!nn_write)
                        nn_rdata = control_reg;

                end


                // =============================================================
                // STATUS
                // =============================================================

                12'h004: begin

                    nn_ready = 1'b1;

                    if (!nn_write) begin

                        nn_rdata = {

                            28'd0,

                           // nn_s_axis_tready,

                            input_valid_reg,

                            output_last_reg,

                            output_valid_reg

                        };

                    end

                end


                // =============================================================
                // VERSION
                // =============================================================

                12'h008: begin

                    nn_ready = 1'b1;

                    if (!nn_write)
                        nn_rdata = 32'h0001_0000;

                end


                // =============================================================
                // INPUT DATA LOW
                // =============================================================

                12'h00C: begin

                    nn_ready = 1'b1;

                    if (!nn_write)
                        nn_rdata = input_data_reg[31:0];

                end


                // =============================================================
                // INPUT DATA HIGH
                // =============================================================

                12'h010: begin

                    nn_ready = 1'b1;

                    if (!nn_write)
                        nn_rdata = input_data_reg[63:32];

                end


                // =============================================================
                // OUTPUT DATA LOW
                // =============================================================

                12'h014: begin

                    nn_ready = 1'b1;

                    if (!nn_write)
                        nn_rdata = output_data_reg[31:0];

                end


                // =============================================================
                // OUTPUT DATA HIGH
                // =============================================================

                12'h018: begin

                    nn_ready = 1'b1;

                    if (!nn_write)
                        nn_rdata = output_data_reg[63:32];

                end


                // =============================================================
                // UNDEFINED REGISTER
                // =============================================================

                default: begin

                    nn_ready = 1'b1;

                    nn_rdata = 32'd0;

                end

            endcase

        end

    end


    // =========================================================================
    // START COMMAND DETECTION
    // =========================================================================
    //
    // START is a COMMAND, not a persistent state.
    //
    // A write of:
    //
    //      CONTROL = 0x0000_0002
    //
    // means:
    //
    //      "Start one input transaction."
    //
    // The value 1 in bit 1 is therefore converted into a one-cycle internal
    // request called start_request.
    //
    // It is NOT stored in control_reg.
    // =========================================================================

    wire axi_start_request;

    wire native_start_request;


    assign axi_start_request =
        axi_write_fire &&
        (s_axi_awaddr[5:2] == 4'h0) &&
        s_axi_wstrb[0] &&
        s_axi_wdata[1];


    assign native_start_request =
        native_write_fire &&
        (nn_addr == 12'h000) &&
        nn_strb[0] &&
        nn_wdata[1];


    // =========================================================================
    // AXI4-STREAM INTERNAL SIGNALS
    // =========================================================================
    //
    // These signals connect the wrapper to the existing axis_nn module.
    //
    // The input transaction is generated from input_data_reg.
    //
    // The output transaction comes directly from axis_nn.
    // =========================================================================

    wire [63:0] nn_s_axis_tdata;

    wire        nn_s_axis_tvalid;

    wire        nn_s_axis_tready;

    wire        nn_s_axis_tlast;


    wire [63:0] nn_m_axis_tdata;

    wire        nn_m_axis_tvalid;

    wire        nn_m_axis_tready;

    wire        nn_m_axis_tlast;


    // =========================================================================
    // AXI4-STREAM INPUT
    // =========================================================================
    //
    // input_data_reg contains the 64-bit data written by the CPU/AXI master.
    //
    // The accelerator receives the data only when:
    //
    //      input_valid_reg = 1
    //      control_reg[0] = 1
    //
    // Thus ENABLE gates the accelerator.
    // =========================================================================

    assign nn_s_axis_tdata = input_data_reg;


    assign nn_s_axis_tvalid =
        input_valid_reg &&
        control_reg[0];


    assign nn_s_axis_tlast =
        input_last_reg;


    // -------------------------------------------------------------------------
    // External AXI4-Stream ready
    //
    // The external ready signal indicates that the accelerator's internal
    // input interface is capable of accepting the generated transaction.
    // -------------------------------------------------------------------------

    assign s_axis_tready =
        nn_s_axis_tready &&
        control_reg[0];


    // =========================================================================
    // AXI4-STREAM OUTPUT
    // =========================================================================
    //
    // The actual AXI4-Stream output of axis_nn is passed through the wrapper.
    //
    // At the same time, a copy is captured into output_data_reg whenever the
    // output transaction completes.
    // =========================================================================

    assign m_axis_tdata =
        nn_m_axis_tdata;


    assign m_axis_tvalid =
        nn_m_axis_tvalid &&
        control_reg[0];


    assign m_axis_tlast =
        nn_m_axis_tlast;


    assign nn_m_axis_tready =
        m_axis_tready &&
        control_reg[0];


    // =========================================================================
    // INPUT TRANSACTION CONTROL
    // =========================================================================
    //
    // START command causes:
    //
    //      input_valid_reg = 1
    //
    // The input remains valid until AXI4-Stream handshake occurs:
    //
    //      TVALID && TREADY
    //
    // This follows the AXI4-Stream handshake convention.
    //
    // Since this implementation represents one 64-bit register as one
    // transaction, TLAST is asserted for that transaction.
    // =========================================================================

    always @(posedge aclk) begin

        if (!aresetn) begin

            input_valid_reg <= 1'b0;

            input_last_reg  <= 1'b1;

        end
        else begin

            // -----------------------------------------------------------------
            // START command
            //
            // AXI4-Lite or PicoRV32 can generate the command.
            // -----------------------------------------------------------------

            if (axi_start_request || native_start_request) begin

                input_valid_reg <= 1'b1;

                input_last_reg  <= 1'b1;

            end


            // -----------------------------------------------------------------
            // AXI4-Stream input handshake
            //
            // Once the accelerator accepts the input:
            //
            //      VALID = 1
            //      READY = 1
            //
            // the pending input transaction is complete.
            // -----------------------------------------------------------------

            if (nn_s_axis_tvalid && nn_s_axis_tready) begin

                input_valid_reg <= 1'b0;

            end

        end

    end


    // =========================================================================
    // OUTPUT DATA CAPTURE
    // =========================================================================
    //
    // Whenever axis_nn completes an output AXI4-Stream transaction:
    //
    //      m_axis_tvalid = 1
    //      m_axis_tready = 1
    //
    // the result is copied into output_data_reg.
    //
    // The CPU can then read:
    //
    //      0x14 -> OUTPUT_DATA_LO
    //      0x18 -> OUTPUT_DATA_HI
    //
    // =========================================================================

    always @(posedge aclk) begin

        if (!aresetn) begin

            output_data_reg  <= 64'd0;

            output_valid_reg <= 1'b0;

            output_last_reg  <= 1'b0;

        end
        else begin

            if (nn_m_axis_tvalid && nn_m_axis_tready) begin

                output_data_reg  <= nn_m_axis_tdata;

                output_valid_reg <= 1'b1;

                output_last_reg  <= nn_m_axis_tlast;

            end

        end

    end


    // =========================================================================
    // EXISTING AXI4-STREAM NN / TPU
    // =========================================================================
    //
    // This is the existing accelerator.
    //
    // The wrapper does NOT modify the internal implementation of axis_nn.
    //
    // The wrapper simply converts:
    //
    //      CPU / AXI4-Lite register programming
    //
    // into:
    //
    //      AXI4-Stream input transaction
    //
    // and captures:
    //
    //      AXI4-Stream output transaction
    //
    // from axis_nn.
    // =========================================================================

    axis_nn axis_nn_inst
    (

        .aclk(aclk),

        .aresetn(aresetn),


        // ---------------------------------------------------------------------
        // AXI4-Stream input
        // ---------------------------------------------------------------------

        .s_axis_tready(nn_s_axis_tready),

        .s_axis_tdata(nn_s_axis_tdata),

        .s_axis_tvalid(nn_s_axis_tvalid),

        .s_axis_tlast(nn_s_axis_tlast),


        // ---------------------------------------------------------------------
        // AXI4-Stream output
        // ---------------------------------------------------------------------

        .m_axis_tready(nn_m_axis_tready),

        .m_axis_tdata(nn_m_axis_tdata),

        .m_axis_tvalid(nn_m_axis_tvalid),

        .m_axis_tlast(nn_m_axis_tlast)

    );


endmodule