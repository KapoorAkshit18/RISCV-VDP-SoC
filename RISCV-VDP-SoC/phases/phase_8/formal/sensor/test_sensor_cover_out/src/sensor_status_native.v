// =============================================================================
// sensor_status_native_slave.v
//
// Read-only telemetry window onto external sensor inputs.
// Exposed through the PicoRV32 native memory interface.
//
// Local address map:
//   0x00  BATTERY_PERCENT   (RO) [7:0]   0-100, unsigned
//   0x04  BATTERY_VOLTAGE   (RO) [15:0]  millivolts, unsigned
//   0x08  TEMPERATURE       (RO) [15:0]  signed, tenths of degree C
//   0x0C  SENSOR_STATUS     (RO) [31:0]
//           bit0 = sensor_valid
//           bit1 = battery_low
//           bit2 = temp_alarm
//           bits[31:3] = 0
//
// Native bus convention:
//   mem_valid = 1, mem_wstrb = 0  -> READ
//   mem_valid = 1, mem_wstrb != 0 -> WRITE
//
// All sensor registers are read-only.
// Writes are accepted and silently discarded.
//
// Unmapped native-bus reads:
//   mem_rdata = 0
//   mem_ready = 1
//
// Unmapped writes:
//   ignored
//   mem_ready = 1
//
// Response timing:
//   Request is accepted in cycle N.
//   mem_ready is asserted in cycle N+1.
//
// Reset:
//   Active-low synchronous reset.
// =============================================================================

module sensor_status_native_slave (
    input  wire        clk,
    input  wire        resetn,

    // PicoRV32 native memory interface
    input  wire        mem_valid,
    input  wire        mem_instr,
    output reg         mem_ready,
    input  wire [11:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,
    output reg  [31:0] mem_rdata,

    // External sensor inputs
    // These may be asynchronous to clk.
    input  wire [7:0]  battery_percent_i,
    input  wire [15:0] battery_voltage_mv_i,
    input  wire [15:0] temperature_tenthsC_i,
    input  wire        sensor_valid_i
);

    // -------------------------------------------------------------------------
    // Local register addresses
    // -------------------------------------------------------------------------
    localparam [11:0] ADDR_BATT_PCT  = 12'h000;
    localparam [11:0] ADDR_BATT_VOLT = 12'h004;
    localparam [11:0] ADDR_TEMP      = 12'h008;
    localparam [11:0] ADDR_STATUS    = 12'h00C;

    // -------------------------------------------------------------------------
    // Sensor thresholds
    // -------------------------------------------------------------------------
    localparam [7:0]  BATT_LOW_THRESH = 8'd15;
    localparam signed [15:0] TEMP_ALARM_HIGH = 16'sd800;

    // -------------------------------------------------------------------------
    // 2-FF synchronizers
    // -------------------------------------------------------------------------
    reg [7:0]  batt_pct_ff1;
    reg [7:0]  batt_pct_sync;

    reg [15:0] batt_volt_ff1;
    reg [15:0] batt_volt_sync;

    reg [15:0] temp_ff1;
    reg [15:0] temp_sync;

    reg        valid_ff1;
    reg        valid_sync;

    // Active-low SYNCHRONOUS reset.
    always @(posedge clk) begin
        if (!resetn) begin
            batt_pct_ff1  <= 8'h00;
            batt_pct_sync <= 8'h00;

            batt_volt_ff1  <= 16'h0000;
            batt_volt_sync <= 16'h0000;

            temp_ff1  <= 16'h0000;
            temp_sync <= 16'h0000;

            valid_ff1  <= 1'b0;
            valid_sync <= 1'b0;
        end
        else begin
            batt_pct_ff1  <= battery_percent_i;
            batt_pct_sync <= batt_pct_ff1;

            batt_volt_ff1  <= battery_voltage_mv_i;
            batt_volt_sync <= batt_volt_ff1;

            temp_ff1  <= temperature_tenthsC_i;
            temp_sync <= temp_ff1;

            valid_ff1  <= sensor_valid_i;
            valid_sync <= valid_ff1;
        end
    end

    // -------------------------------------------------------------------------
    // Derived sensor status
    // -------------------------------------------------------------------------
    wire battery_low;
    wire temp_alarm;
    wire [31:0] status_word;

    assign battery_low = (batt_pct_sync <= BATT_LOW_THRESH);

    assign temp_alarm =
        ($signed(temp_sync) > TEMP_ALARM_HIGH);

    assign status_word =
        {29'h00000000, temp_alarm, battery_low, valid_sync};

    // -------------------------------------------------------------------------
    // Native-bus transaction state
    //
    // pending_request:
    //   0 = no request waiting for response
    //   1 = request captured, response will be returned this cycle
    //
    // This gives fixed one-cycle response latency:
    //
    //   Cycle N:
    //       mem_valid = 1
    //       mem_ready = 0
    //
    //   Cycle N+1:
    //       mem_ready = 1
    //       mem_rdata = captured response
    // -------------------------------------------------------------------------
    reg        pending_request;
    reg [31:0] response_data;

    always @(posedge clk) begin
        if (!resetn) begin
            pending_request <= 1'b0;
            response_data   <= 32'h00000000;

            mem_ready <= 1'b0;
            mem_rdata <= 32'h00000000;
        end
        else begin

            // Default: no response unless a request was pending.
            mem_ready <= pending_request;

            if (pending_request) begin
                // Present the response for the transaction captured
                // during the previous cycle.
                mem_rdata <= response_data;

                // Complete this transaction.
                pending_request <= 1'b0;
            end
            else if (mem_valid) begin
                // Capture a new native-bus transaction.
                pending_request <= 1'b1;

                // -----------------------------------------------------------------
                // READ
                // -----------------------------------------------------------------
                if (mem_wstrb == 4'b0000) begin

                    case (mem_addr)

                        ADDR_BATT_PCT: begin
                            response_data <= {
                                24'h000000,
                                batt_pct_sync
                            };
                        end

                        ADDR_BATT_VOLT: begin
                            response_data <= {
                                16'h0000,
                                batt_volt_sync
                            };
                        end

                        ADDR_TEMP: begin
                            // Preserve the 16-bit signed sensor representation
                            // in the lower half of the 32-bit result.
                            response_data <= {
                                16'h0000,
                                temp_sync
                            };
                        end

                        ADDR_STATUS: begin
                            response_data <= status_word;
                        end

                        default: begin
                            // Native bus has no SLVERR.
                            // Unmapped read completes with zero.
                            response_data <= 32'h00000000;
                        end

                    endcase
                end

                // -----------------------------------------------------------------
                // WRITE
                // -----------------------------------------------------------------
                else begin
                    // All sensor registers are read-only.
                    // Writes are accepted and silently discarded.
                    //
                    // mem_wdata and mem_wstrb are intentionally unused.
                    response_data <= 32'h00000000;
                end
            end
        end
    end

endmodule
