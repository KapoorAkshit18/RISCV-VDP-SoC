`ifndef SENSOR_RNM_IF_SV
`define SENSOR_RNM_IF_SV

`timescale 1ns/1ps

interface sensor_rnm_if #(
    parameter int ADC_BITS = 12
)(
    input logic clk
);

    // ============================================================
    // RNM / analog-domain signals
    // ============================================================

    real temperature;
    real sensor_voltage;

    // ============================================================
    // ADC digital output
    // ============================================================

    logic [ADC_BITS-1:0] adc_code;

endinterface

`endif
