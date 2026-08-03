// =============================================================================
// sensor_status_axi_slave.v
// Read-only telemetry window onto external sensor inputs, exposed over AXI4-Lite.
// Local address map:
//   0x00  BATTERY_PERCENT   (RO) [7:0]   0-100, unsigned
//   0x04  BATTERY_VOLTAGE   (RO) [15:0]  millivolts, unsigned
//   0x08  TEMPERATURE       (RO) [15:0]  signed, in tenths of a degree C (e.g. 235 = 23.5C)
//   0x0C  SENSOR_STATUS     (RO) [31:0]  bit0 = sensor_valid, bit1 = battery_low,
//                                        bit2 = temp_alarm, bits[31:3] = 0
// All registers are RO -> any write is accepted on the bus (BRESP=OKAY) but dropped.
// All other offsets: read -> 0 with SLVERR.
// No global address decoder here (see INTERFACE_SPEC.md).
// =============================================================================
module sensor_status_axi_slave (
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,

    input  wire [11:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,

    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,

    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [11:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,

    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    // Peripheral-side sensor inputs (raw, asynchronous to bus in general;
    // synchronized below with a 2-FF chain)
    input  wire [7:0]  battery_percent_i,
    input  wire [15:0] battery_voltage_mv_i,
    input  wire [15:0] temperature_tenthsC_i,
    input  wire        sensor_valid_i
);

    localparam ADDR_BATT_PCT   = 12'h000;
    localparam ADDR_BATT_VOLT  = 12'h004;
    localparam ADDR_TEMP       = 12'h008;
    localparam ADDR_STATUS     = 12'h00C;

    localparam BATT_LOW_THRESH  = 8'd15;   // <=15% => battery_low
    localparam TEMP_ALARM_HIGH  = 16'sd800; // > 80.0C => temp_alarm

    // 2-FF synchronizers for all external sensor inputs
    reg [7:0]  batt_pct_ff1,  batt_pct_sync;
    reg [15:0] batt_volt_ff1, batt_volt_sync;
    reg [15:0] temp_ff1,      temp_sync;
    reg        valid_ff1,     valid_sync;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            batt_pct_ff1  <= 8'h0;  batt_pct_sync  <= 8'h0;
            batt_volt_ff1 <= 16'h0; batt_volt_sync <= 16'h0;
            temp_ff1      <= 16'h0; temp_sync      <= 16'h0;
            valid_ff1     <= 1'b0;  valid_sync     <= 1'b0;
        end else begin
            batt_pct_ff1  <= battery_percent_i;      batt_pct_sync  <= batt_pct_ff1;
            batt_volt_ff1 <= battery_voltage_mv_i;    batt_volt_sync <= batt_volt_ff1;
            temp_ff1      <= temperature_tenthsC_i;   temp_sync      <= temp_ff1;
            valid_ff1     <= sensor_valid_i;          valid_sync     <= valid_ff1;
        end
    end

    wire battery_low = (batt_pct_sync <= BATT_LOW_THRESH);
    wire temp_alarm  = ($signed(temp_sync) > TEMP_ALARM_HIGH);
    wire [31:0] status_word = {28'h0, temp_alarm, battery_low, valid_sync};

    // ---- Write channel: accept & discard (registers are RO) ----
    reg aw_hs, w_hs;
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            aw_hs         <= 1'b0;
            w_hs          <= 1'b0;
        end else begin
            if (s_axi_awvalid && !aw_hs && !s_axi_bvalid) begin
                s_axi_awready <= 1'b1;
                aw_hs         <= 1'b1;
            end else s_axi_awready <= 1'b0;

            if (s_axi_wvalid && !w_hs && !s_axi_bvalid) begin
                s_axi_wready <= 1'b1;
                w_hs         <= 1'b1;
            end else s_axi_wready <= 1'b0;

            if (aw_hs && w_hs && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;   // OKAY, write silently dropped (RO region)
                s_axi_bresp  <= 2'b00;
                aw_hs <= 1'b0; w_hs <= 1'b0;
            end
            if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 1'b0;
        end
    end

    // ---- Read channel ----
    reg [11:0] araddr_latched;
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_arready  <= 1'b0;
            s_axi_rvalid   <= 1'b0;
            s_axi_rdata    <= 32'h0;
            s_axi_rresp    <= 2'b00;
            araddr_latched <= 12'h0;
        end else begin
            if (s_axi_arvalid && !s_axi_arready && !s_axi_rvalid) begin
                s_axi_arready  <= 1'b1;
                araddr_latched <= s_axi_araddr;
            end else s_axi_arready <= 1'b0;

            if (s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                case (araddr_latched)
                    ADDR_BATT_PCT:  begin s_axi_rdata <= {24'h0, batt_pct_sync};  s_axi_rresp <= 2'b00; end
                    ADDR_BATT_VOLT: begin s_axi_rdata <= {16'h0, batt_volt_sync}; s_axi_rresp <= 2'b00; end
                    ADDR_TEMP:      begin s_axi_rdata <= {16'h0, temp_sync};      s_axi_rresp <= 2'b00; end
                    ADDR_STATUS:    begin s_axi_rdata <= status_word;             s_axi_rresp <= 2'b00; end
                    default:        begin s_axi_rdata <= 32'h0;                   s_axi_rresp <= 2'b10; end
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
