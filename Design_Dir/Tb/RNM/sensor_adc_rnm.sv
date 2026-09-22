`ifndef SENSOR_ADC_RNM_SV
`define SENSOR_ADC_RNM_SV

`timescale 1ns/1ps

module sensor_adc_rnm #(
    parameter int ADC_BITS = 12,
    parameter real VREF    = 1.8,
    parameter real V_OFFSET = 0.5,
    parameter real V_PER_DEG = 0.01
)(
    input  logic [ADC_BITS-1:0] adc_code,

    output logic signed [15:0] temperature_tenthsC,
    output logic               sensor_valid
);

    localparam int unsigned MAX_CODE = (1 << ADC_BITS) - 1;

    real adc_voltage;
    real temperature_degC;
    integer temperature_scaled;

    always_comb begin

        // ============================================================
        // ADC code -> sensor voltage
        // ============================================================

        adc_voltage =
            (adc_code * VREF) / MAX_CODE;

        // ============================================================
        // Sensor voltage -> temperature
        //
        // V_sensor = V_OFFSET + V_PER_DEG * Temperature
        //
        // Therefore:
        //
        // Temperature =
        //     (V_sensor - V_OFFSET) / V_PER_DEG
        // ============================================================

        temperature_degC =
            (adc_voltage - V_OFFSET) / V_PER_DEG;

        // ============================================================
        // Convert °C to tenths of °C
        //
        // Example:
        //
        // 25.0 °C -> 250
        // 85.0 °C -> 850
        // 80.1 °C -> 801
        // ============================================================

        temperature_scaled =
            $rtoi(temperature_degC * 10.0);

        temperature_tenthsC =
            temperature_scaled;

        // ============================================================
        // Valid temperature range
        // ============================================================

        sensor_valid =
            (temperature_degC >= -40.0) &&
            (temperature_degC <= 125.0);

    end

endmodule

`endif