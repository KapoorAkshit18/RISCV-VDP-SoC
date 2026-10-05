% =============================================================================
% tpu_matmul_verify.m
%
% Matrix multiplication verification for firmware_test03.
%
% This script decodes the exact Q5.10 fixed-point constants from
% firmware_test03/main.c and performs the equivalent forward pass in
% floating-point MATLAB, matching what the TPU hardware computes.
%
% firmware_test03 constants (hex):
%   weight0 = 0x0000B07A0505057A
%   weight1 = 0x0000FC6603E10314
%   weight2 = 0x0000FC70028F0433
%   weight3 = 0xF5A30051FAC21870
%   weight4 = 0x00CC07E10685E399
%   input0  = 0x1400140020002000
%   input1  = 0x1400200014002000
%
% Q5.10 decode: float = int16(hex) / 1024
%
% AXI-Stream beat / matrix mapping:
%   weight0 [w0,w1,w2,w3] -> wb2 row 0, cols [0,1,2,bias]
%   weight1 [w0,w1,w2,w3] -> wb2 row 1, cols [0,1,2,bias]
%   weight2 [w0,w1,w2,w3] -> wb2 row 2, cols [0,1,2,bias]
%   weight3 [w0,w1,w2,w3] -> wb3 row 0, cols [0,1,2,3(bias)]
%   weight4 [w0,w1,w2,w3] -> wb3 row 1, cols [0,1,2,3(bias)]
%   input0  [w0,w1,w2,w3] -> k   row 0, cols [0,1,2,3]
%   input1  [w0,w1,w2,w3] -> k   row 1, cols [0,1,2,3]
% =============================================================================

clear; clc;

%% -------------------------------------------------------------------------
%  1. Q5.10 decode helper
%     pack64 layout: bits[15:0]=w0, bits[31:16]=w1, bits[47:32]=w2, bits[63:48]=w3
% -------------------------------------------------------------------------

% Extract a 16-bit slice from a uint64, sign-extend via typecast, then scale
q510 = @(h) double(typecast(uint16(bitand(h, uint64(0xFFFF))), 'int16')) / 1024.0;

unpack = @(reg64) [
    q510(reg64)
    q510(bitshift(reg64, -16))
    q510(bitshift(reg64, -32))
    q510(bitshift(reg64, -48))
]';   % 1x4 row vector

%% -------------------------------------------------------------------------
%  2. Decode firmware_test03 register constants
%
%  hex2dec loses precision on 64-bit values in MATLAB (double only has 53-bit
%  mantissa). Use typecast from byte array instead.
% -------------------------------------------------------------------------

hex64 = @(s) typecast( ...
    uint8(fliplr(reshape(sscanf(s, '%2x'), 1, []))), 'uint64');

w0_reg = unpack(hex64('0000B07A0505057A'));
w1_reg = unpack(hex64('0000FC6603E10314'));
w2_reg = unpack(hex64('0000FC70028F0433'));
w3_reg = unpack(hex64('F5A30051FAC21870'));
w4_reg = unpack(hex64('00CC07E10685E399'));
i0_reg = unpack(hex64('1400140020002000'));
i1_reg = unpack(hex64('1400200014002000'));

fprintf('--- Decoded Q5.10 register values ---\n');
fprintf('weight0: %7.3f %7.3f %7.3f %7.3f\n', w0_reg);
fprintf('weight1: %7.3f %7.3f %7.3f %7.3f\n', w1_reg);
fprintf('weight2: %7.3f %7.3f %7.3f %7.3f\n', w2_reg);
fprintf('weight3: %7.3f %7.3f %7.3f %7.3f\n', w3_reg);
fprintf('weight4: %7.3f %7.3f %7.3f %7.3f\n', w4_reg);
fprintf('input0:  %7.3f %7.3f %7.3f %7.3f\n', i0_reg);
fprintf('input1:  %7.3f %7.3f %7.3f %7.3f\n\n', i1_reg);

%% -------------------------------------------------------------------------
%  3. Reconstruct matrices
%
%  wb2 (3x3): each weight row has 3 neuron weights + 1 bias (col index 2 = bias)
%             col 3 of weight register is unused (zero) for layer 2
%  wb3 (2x4): each weight row has 3 neuron weights + 1 bias (col index 3 = bias)
%  k   (2x4): raw input matrix, 4 columns = 4 samples
% -------------------------------------------------------------------------

% wb2: take cols [0,1,2] from weight0/1/2 (col 3 is zero padding)
wb2 = [w0_reg(1:3);
       w1_reg(1:3);
       w2_reg(1:3)];

% wb3: take all 4 cols from weight3/4
wb3 = [w3_reg;
       w4_reg];

% k: input rows
k = [i0_reg;
     i1_reg];

fprintf('--- Reconstructed matrices ---\n');
disp('wb2 ='); disp(wb2);
disp('wb3 ='); disp(wb3);
disp('k   ='); disp(k);

%% -------------------------------------------------------------------------
%  4. Forward pass  (mirrors MATLAB reference script)
%
%  k_padded  = cat(1, k, ones(1,4))       % append bias row
%  z2        = wb2 * k_padded             % 3x4
%  a2        = sigmoid(z2)
%  a2_padded = cat(1, a2, ones(1,4))      % append bias row
%  z3        = wb3 * a2_padded            % 2x4
%  a3        = sigmoid(z3)
%  a3_rounded = round(a3)
% -------------------------------------------------------------------------

sigmoid = @(x) 1 ./ (1 + exp(-x));

k_padded  = cat(1, k, ones(1, 4));
z2        = wb2 * k_padded;
a2        = sigmoid(z2);

a2_padded = cat(1, a2, ones(1, 4));
z3        = wb3 * a2_padded;
a3        = sigmoid(z3);

a3_rounded = round(a3);

%% -------------------------------------------------------------------------
%  5. Display results
% -------------------------------------------------------------------------

fprintf('--- Forward pass results ---\n');
disp('k_padded =');  disp(k_padded);
disp('z2 =');        disp(z2);
disp('a2 =');        disp(a2);
disp('a2_padded ='); disp(a2_padded);
disp('z3 =');        disp(z3);
disp('a3 =');        disp(a3);
disp('a3_rounded =');disp(a3_rounded);

%% -------------------------------------------------------------------------
%  6. Expected TPU result registers (Q5.10 re-encode for comparison)
%
%  result0 holds a3 row 0: [col0, col1, col2, col3]
%  result1 holds a3 row 1: [col0, col1, col2, col3]
%  bits[15:0]=col0 ... bits[63:48]=col3
% -------------------------------------------------------------------------

to_q510 = @(f) uint16(int16(round(f * 1024)));

pack_result = @(row) ...
    bitor(bitor(bitor( ...
        uint64(to_q510(row(1))), ...
        bitshift(uint64(to_q510(row(2))), 16)), ...
        bitshift(uint64(to_q510(row(3))), 32)), ...
        bitshift(uint64(to_q510(row(4))), 48));

expected_result0 = pack_result(a3(1,:));
expected_result1 = pack_result(a3(2,:));

fprintf('--- Expected TPU result registers (Q5.10) ---\n');
fprintf('result0 = 0x%s  (a3 row 0)\n', dec2hex(expected_result0, 16));
fprintf('result1 = 0x%s  (a3 row 1)\n\n', dec2hex(expected_result1, 16));

% Cross-check against known UVM simulation result
uvm_result0 = hex64('0014001c001f02a9');
uvm_result1 = hex64('03e803e003dc00ba');
fprintf('--- Cross-check vs UVM simulation ---\n');
fprintf('UVM result0 = 0x%s\n', dec2hex(uvm_result0, 16));
fprintf('UVM result1 = 0x%s\n', dec2hex(uvm_result1, 16));
fprintf('MATLAB match result0: %d\n', expected_result0 == uvm_result0);
fprintf('MATLAB match result1: %d\n\n', expected_result1 == uvm_result1);

% Decode UVM results back to float for inspection
uvm_a3_row0 = unpack(uvm_result0);
uvm_a3_row1 = unpack(uvm_result1);
fprintf('UVM a3 row0 (float): %7.4f %7.4f %7.4f %7.4f\n', uvm_a3_row0);
fprintf('UVM a3 row1 (float): %7.4f %7.4f %7.4f %7.4f\n', uvm_a3_row1);
fprintf('UVM a3 row0 (round): %d %d %d %d\n', round(uvm_a3_row0));
fprintf('UVM a3 row1 (round): %d %d %d %d\n\n', round(uvm_a3_row1));

%% -------------------------------------------------------------------------
%  7. Per-column summary table
% -------------------------------------------------------------------------

fprintf('--- Per-sample output summary ---\n');
fprintf('%-8s %-12s %-12s %-12s %-12s\n', ...
        '', 'sample 0', 'sample 1', 'sample 2', 'sample 3');
fprintf('%-8s %-12.4f %-12.4f %-12.4f %-12.4f\n', ...
        'a3(1,:)', a3(1,1), a3(1,2), a3(1,3), a3(1,4));
fprintf('%-8s %-12.4f %-12.4f %-12.4f %-12.4f\n', ...
        'a3(2,:)', a3(2,1), a3(2,2), a3(2,3), a3(2,4));
fprintf('%-8s %-12d %-12d %-12d %-12d\n', ...
        'rnd(1,:)', a3_rounded(1,1), a3_rounded(1,2), a3_rounded(1,3), a3_rounded(1,4));
fprintf('%-8s %-12d %-12d %-12d %-12d\n', ...
        'rnd(2,:)', a3_rounded(2,1), a3_rounded(2,2), a3_rounded(2,3), a3_rounded(2,4));
