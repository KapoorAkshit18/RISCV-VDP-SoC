#!/bin/bash
cp phases/phase_7/fault_models/nn_axis_master.v phases/phase_7/mutation_testing/mutants/tpu_control/M06_nn_axis_master.v
sed -i "s/axis_busy       <= 1'b1;/axis_busy       <= 1'b0; \/\/ MUTATION: BUSY stuck 0/g" phases/phase_7/mutation_testing/mutants/tpu_control/M06_nn_axis_master.v
