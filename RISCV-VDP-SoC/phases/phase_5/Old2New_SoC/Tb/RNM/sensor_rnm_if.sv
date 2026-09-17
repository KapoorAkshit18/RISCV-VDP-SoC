`ifndef SENSOR_RNM_IF_SV
`define SENSOR_RNM_IF_SV

`timescale 1ns/1ps

interface sensor_rnm_if #(
    parameter int ADC_BITS = 12
)(
    input logic clk
);

    // Analog/RNM domain
    real temperature;
    real sensor_voltage;

    // Digital ADC output
    logic [ADC_BITS-1:0] adc_code;

endinterface

`endif