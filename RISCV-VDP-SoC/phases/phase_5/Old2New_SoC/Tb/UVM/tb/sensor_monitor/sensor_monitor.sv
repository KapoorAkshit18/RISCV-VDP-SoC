`ifndef SENSOR_MONITOR_SV
`define SENSOR_MONITOR_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// RISCV-VDP-SoC
// SENSOR Monitor
//
// Subscribes to the native-bus soc_monitor stream.
//   - Forwards SENSOR-window transactions on analysis_port
//   - Detects firmware completion through the RAM debug marker
//     and triggers sensor_done_event
//
// Connect in soc_env:
//   native_agent.monitor.analysis_port.connect(sensor_mon.analysis_export);
// =============================================================================

class sensor_monitor extends uvm_subscriber #(soc_sequence_item);

    `uvm_component_utils(sensor_monitor)

    // Event the test waits on
    event sensor_done_event;

    // SENSOR-only transactions (optional consumer, e.g. future scoreboard)
    uvm_analysis_port #(soc_sequence_item) analysis_port;

    // Sensor MMIO window
    localparam bit [31:0] SENSOR_BASE       = 32'h0001_2000;
    localparam bit [31:0] SENSOR_END        = 32'h0001_2FFF;
    localparam bit [31:0] SENSOR_TEMP_OFF   = 32'h0000_0008; // SENSOR_TEMPERATURE
    localparam bit [31:0] SENSOR_STATUS_OFF = 32'h0000_000C; // SENSOR_STATUS

    localparam int TEMP_ALARM_HIGH = 800; // tenths of degC, matches firmware

    // Firmware completion protocol (matches sensor firmware)
    localparam bit [31:0] DEBUG_MARKER = 32'h0000_12A8;
    localparam bit [31:0] DEBUG_ERROR  = 32'h0000_12AC;
    localparam bit [31:0] MARK_SUCCESS = 32'h5555_5555;
    localparam bit [31:0] MARK_ERROR   = 32'hDEAD_0001;

    int unsigned sensor_txn_count;
    bit          done_seen;
    bit [31:0]   last_error_code;

    // Latched from the temperature/status reads, for the SENSORLOG/ALARM
    // lines consumed by the sweep parser (parse_results.py)
    bit signed [15:0] last_temp_read;
    bit               last_temp_read_valid;


    function new(string name = "sensor_monitor", uvm_component parent = null);
        super.new(name, parent);
        analysis_port = new("analysis_port", this);
    endfunction


    virtual function void write(soc_sequence_item t);

        // Forward sensor-window traffic
        if (t.addr >= SENSOR_BASE && t.addr <= SENSOR_END) begin
            sensor_txn_count++;
            analysis_port.write(t);

            // --- SENSORLOG: temperature register read -------------------
            // Consumed by parse_results.py: "SENSORLOG,TEMP,<temp_read_tenths>"
            if (!t.write && t.addr == SENSOR_BASE + SENSOR_TEMP_OFF) begin
                last_temp_read       = $signed(t.rdata[15:0]);
                last_temp_read_valid = 1'b1;
                $display("SENSORLOG,TEMP,%0d", last_temp_read);
            end

            // --- ALARM: expected vs actual temp-alarm bit ----------------
            // Consumed by parse_results.py: "ALARM,<expected>,<actual>"
            // Expected is computed from the temperature reading already
            // latched above; actual comes from the STATUS register's
            // TEMP_ALARM bit (bit 2), same convention as the firmware.
            if (!t.write && t.addr == SENSOR_BASE + SENSOR_STATUS_OFF) begin
                bit actual_alarm   = t.rdata[2];
                bit expected_alarm = last_temp_read_valid &&
                                      (last_temp_read > TEMP_ALARM_HIGH);
                $display("ALARM,%0d,%0d", expected_alarm, actual_alarm);
            end
        end

        // Remember the error code the firmware stores before MARK_ERROR
        if (t.write && t.addr == DEBUG_ERROR)
            last_error_code = t.wdata;

        // Completion is signalled through the RAM marker
        if (!done_seen && t.write && t.addr == DEBUG_MARKER) begin

            if (t.wdata == MARK_SUCCESS) begin
                done_seen = 1;
                `uvm_info("SENSOR_MON",
                    $sformatf("Firmware SUCCESS marker seen (%0d sensor txns)",
                              sensor_txn_count), UVM_LOW)
                ->sensor_done_event;
            end
            else if (t.wdata == MARK_ERROR) begin
                done_seen = 1;
                `uvm_error("SENSOR_MON",
                    $sformatf("Firmware reported ERROR, code=%0d", last_error_code))
                ->sensor_done_event;
            end
        end

    endfunction


    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SENSOR_MON",
            $sformatf("sensor txns=%0d done_seen=%0b", sensor_txn_count, done_seen),
            UVM_NONE)
    endfunction

endclass

`endif