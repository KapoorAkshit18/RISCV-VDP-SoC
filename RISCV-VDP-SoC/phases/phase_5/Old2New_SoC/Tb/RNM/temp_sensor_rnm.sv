`ifndef TEMP_SENSOR_RNM_SV
`define TEMP_SENSOR_RNM_SV

module temp_sensor_rnm #(
    parameter real V_OFFSET = 0.5,
    parameter real V_PER_DEG = 0.01,
    parameter bit ENABLE_NOISE = 1'b1
)(
    input  real temperature,
    output real sensor_voltage
);


    real noise;

    always @(*)
    
    begin

        if (ENABLE_NOISE)
    noise = (($urandom % 10001) / 10000.0) * 0.01 - 0.005;
else
    noise = 0.0;

        if (temperature < -40.0 || temperature > 125.0)
            $error("Temperature out of range: %f", temperature);

        noise = (($urandom % 10001) / 10000.0) * 0.01 - 0.005;

        sensor_voltage = V_OFFSET
                       + (V_PER_DEG * temperature)
                       + noise;

    end

endmodule

`endif