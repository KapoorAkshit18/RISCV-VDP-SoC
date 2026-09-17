`ifndef TB_RNM_SV
`define TB_RNM_SV

`timescale 1ns/1ps

module tb_rnm;

    // ============================================================
    // RNM parameters
    // ============================================================

    parameter int ADC_BITS = 12;
    parameter real VREF    = 1.8;

    // ============================================================
    // RNM signals
    // ============================================================

    real temperature;
    real sensor_voltage;

    logic [ADC_BITS-1:0] adc_code;

    // ============================================================
    // Temperature sensor RNM
    // ============================================================

    temp_sensor_rnm #(
        .V_OFFSET (0.5),
        .V_PER_DEG(0.01)
    ) u_temp_sensor (
        .temperature   (temperature),
        .sensor_voltage(sensor_voltage)
    );

    // ============================================================
    // ADC RNM
    // ============================================================

    adc_rnm #(
        .ADC_BITS(ADC_BITS),
        .VREF    (VREF)
    ) u_adc (
        .analog_voltage(sensor_voltage),
        .adc_code      (adc_code)
    );

    // ============================================================
    // Test
    // ============================================================

    initial begin

        $display("============================================================");
        $display(" Temperature Sensor + ADC RNM Test");
        $display(" ADC_BITS = %0d, VREF = %0.3f V", ADC_BITS, VREF);
        $display("============================================================");
        $display(" Temp(C)   Sensor Voltage(V)   ADC Code");
        $display("------------------------------------------------------------");

        temperature = -40.0;
        #10;
        $display(" %7.1f   %17.6f   %0d",
                 temperature, sensor_voltage, adc_code);

        temperature = 0.0;
        #10;
        $display(" %7.1f   %17.6f   %0d",
                 temperature, sensor_voltage, adc_code);

        temperature = 25.0;
        #10;
        $display(" %7.1f   %17.6f   %0d",
                 temperature, sensor_voltage, adc_code);

        temperature = 85.0;
        #10;
        $display(" %7.1f   %17.6f   %0d",
                 temperature, sensor_voltage, adc_code);

        temperature = 125.0;
        #10;
        $display(" %7.1f   %17.6f   %0d",
                 temperature, sensor_voltage, adc_code);

        // ADC saturation test
        temperature = 200.0;
        #10;
        $display(" %7.1f   %17.6f   %0d  <-- saturation test",
                 temperature, sensor_voltage, adc_code);

        $display("============================================================");

        $finish;
    end

endmodule

`endif