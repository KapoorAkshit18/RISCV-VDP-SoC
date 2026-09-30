`ifndef TEMP_SENSOR_RNM_SV
`define TEMP_SENSOR_RNM_SV

`timescale 1ns/1ps

// =============================================================================
// noise_en is now a runtime INPUT, not a compile-time parameter. This lets a
// single compiled build sweep both noise-off (deterministic) and noise-on
// (statistical) runs via +NOISE_ON, instead of needing a recompile or a
// hierarchical parameter override per run.
// =============================================================================

module temp_sensor_rnm #(
    parameter real V_OFFSET  = 0.5,
    parameter real V_PER_DEG = 0.01
)(
    input  real  temperature,
    input  logic noise_en,
    output real  sensor_voltage
);

    real noise;

    // always_comb also evaluates once at time 0, so a temperature set at
    // time 0 by the testbench is never missed.
    always_comb begin

        if (noise_en)
            noise = (($urandom % 10001) / 10000.0) * 0.01 - 0.005;
        else
            noise = 0.0;

        if (temperature < -40.0 || temperature > 125.0)
            $error("Temperature out of range: %f", temperature);

        sensor_voltage = V_OFFSET
                       + (V_PER_DEG * temperature)
                       + noise;

    end

endmodule

`endif