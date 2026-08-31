`timescale 1ns / 1ps

module nn_axi_wrapper #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6
)(
    // ============================================================
    // Clock / Reset
    // ============================================================
    input  wire aclk,
    input  wire aresetn,

    // ============================================================
    // AXI4-Lite Slave Interface
    // ============================================================
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

    // ============================================================
    // AXI4-Stream Input
    // ============================================================
    input  wire [63:0] s_axis_tdata,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,
    input  wire         s_axis_tlast,

    // ============================================================
    // AXI4-Stream Output
    // ============================================================
    output wire [63:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

    // ============================================================
    // AXI4-Lite registers
    //
    // 0x00 : CONTROL
    //        bit 0 = enable
    //
    // 0x04 : STATUS
    //        bit 0 = output valid
    //        bit 1 = output last
    //        bit 2 = input valid
    //        bit 3 = input ready
    //
    // 0x08 : VERSION
    //        32'h0001_0000
    // ============================================================

    reg [31:0] control_reg;

    reg [31:0] axi_rdata_reg;
    reg        axi_rvalid_reg;

    reg        axi_bvalid_reg;

    reg        awready_reg;
    reg        wready_reg;
    reg        arready_reg;

    assign s_axi_awready = awready_reg;
    assign s_axi_wready  = wready_reg;

    assign s_axi_bvalid = axi_bvalid_reg;
    assign s_axi_bresp  = 2'b00;       // OKAY

    assign s_axi_arready = arready_reg;

    assign s_axi_rdata  = axi_rdata_reg;
    assign s_axi_rvalid = axi_rvalid_reg;
    assign s_axi_rresp  = 2'b00;        // OKAY


    // ============================================================
    // AXI4-Lite Write Channel
    // ============================================================

    always @(posedge aclk) begin
        if (!aresetn) begin
            control_reg   <= 32'd0;

            axi_bvalid_reg <= 1'b0;

            awready_reg <= 1'b1;
            wready_reg  <= 1'b1;
        end
        else begin

            // ----------------------------------------------------
            // Accept write transaction
            // ----------------------------------------------------
            if (s_axi_awvalid && s_axi_wvalid &&
                awready_reg && wready_reg) begin

                case (s_axi_awaddr[5:2])

                    // CONTROL register
                    4'h0: begin
                        if (s_axi_wstrb[0])
                            control_reg[7:0] <= s_axi_wdata[7:0];

                        if (s_axi_wstrb[1])
                            control_reg[15:8] <= s_axi_wdata[15:8];

                        if (s_axi_wstrb[2])
                            control_reg[23:16] <= s_axi_wdata[23:16];

                        if (s_axi_wstrb[3])
                            control_reg[31:24] <= s_axi_wdata[31:24];
                    end

                    default: begin
                        // Ignore writes to undefined registers
                    end

                endcase

                axi_bvalid_reg <= 1'b1;

                awready_reg <= 1'b0;
                wready_reg  <= 1'b0;
            end

            // ----------------------------------------------------
            // Write response accepted
            // ----------------------------------------------------
            if (axi_bvalid_reg && s_axi_bready) begin
                axi_bvalid_reg <= 1'b0;

                awready_reg <= 1'b1;
                wready_reg  <= 1'b1;
            end
        end
    end


    // ============================================================
    // AXI4-Lite Read Channel
    // ============================================================

    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_rdata_reg  <= 32'd0;
            axi_rvalid_reg <= 1'b0;
            arready_reg    <= 1'b1;
        end
        else begin

            // ----------------------------------------------------
            // Accept read request
            // ----------------------------------------------------
            if (s_axi_arvalid && arready_reg) begin

                case (s_axi_araddr[5:2])

                    // CONTROL
                    4'h0: begin
                        axi_rdata_reg <= control_reg;
                    end

                    // STATUS
                    4'h1: begin
                        axi_rdata_reg <= {
                            28'd0,
                            s_axis_tready,
                            s_axis_tvalid,
                            m_axis_tlast,
                            m_axis_tvalid
                        };
                    end

                    // VERSION
                    4'h2: begin
                        axi_rdata_reg <= 32'h0001_0000;
                    end

                    default: begin
                        axi_rdata_reg <= 32'd0;
                    end

                endcase

                axi_rvalid_reg <= 1'b1;
                arready_reg    <= 1'b0;
            end

            // ----------------------------------------------------
            // Read data accepted
            // ----------------------------------------------------
            if (axi_rvalid_reg && s_axi_rready) begin
                axi_rvalid_reg <= 1'b0;
                arready_reg    <= 1'b1;
            end
        end
    end


    // ============================================================
    // AXI4-Stream connection to existing axis_nn
    // ============================================================

    wire [63:0] nn_s_axis_tdata;
    wire        nn_s_axis_tvalid;
    wire        nn_s_axis_tready;
    wire        nn_s_axis_tlast;

    wire [63:0] nn_m_axis_tdata;
    wire        nn_m_axis_tvalid;
    wire        nn_m_axis_tready;
    wire        nn_m_axis_tlast;


    // ------------------------------------------------------------
    // Enable controlled by AXI4-Lite CONTROL register
    // bit 0 = 1 -> accelerator enabled
    // ------------------------------------------------------------

    assign nn_s_axis_tdata  = s_axis_tdata;
    assign nn_s_axis_tvalid = s_axis_tvalid & control_reg[0];
    assign nn_s_axis_tlast  = s_axis_tlast;

    assign s_axis_tready =
            nn_s_axis_tready & control_reg[0];


    assign m_axis_tdata  = nn_m_axis_tdata;
    assign m_axis_tvalid = nn_m_axis_tvalid & control_reg[0];
    assign m_axis_tlast  = nn_m_axis_tlast;

    assign nn_m_axis_tready =
            m_axis_tready & control_reg[0];


    // ============================================================
    // Existing NN
    // ============================================================

    axis_nn axis_nn_inst
    (
        .aclk(aclk),
        .aresetn(aresetn),

        // AXI4-Stream input
        .s_axis_tready(nn_s_axis_tready),
        .s_axis_tdata(nn_s_axis_tdata),
        .s_axis_tvalid(nn_s_axis_tvalid),
        .s_axis_tlast(nn_s_axis_tlast),

        // AXI4-Stream output
        .m_axis_tready(nn_m_axis_tready),
        .m_axis_tdata(nn_m_axis_tdata),
        .m_axis_tvalid(nn_m_axis_tvalid),
        .m_axis_tlast(nn_m_axis_tlast)
    );

endmodule