`ifndef ADC_RNM_SV
`define ADC_RNM_SV

`timescale 1ns/1ps

module adc_rnm #(
    parameter int ADC_BITS = 12,
    parameter real VREF    = 1.8
)(
    input  real analog_voltage,
    output logic [ADC_BITS-1:0] adc_code
);

    localparam int unsigned MAX_CODE = (1 << ADC_BITS) - 1;

    real scaled_code;
    int unsigned quantized_code;

    always_comb begin

        // Saturation at lower limit
        if (analog_voltage <= 0.0) begin
            quantized_code = 0;
        end

        // Saturation at upper limit
        else if (analog_voltage >= VREF) begin
            quantized_code = MAX_CODE;
        end

        // ADC quantization
        else begin
            scaled_code = (analog_voltage / VREF) * MAX_CODE;
            quantized_code = $rtoi(scaled_code);
        end

        adc_code = quantized_code[ADC_BITS-1:0];

    end

endmodule

`endif