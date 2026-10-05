# matlab_verification

MATLAB forward-pass verification for `firmware_test03`.

## File

| File | Purpose |
|---|---|
| `tpu_matmul_verify.m` | Decodes firmware_test03 Q5.10 constants and runs the full forward pass |

## What it does

1. Decodes the 7 x 64-bit register constants from `firmware_test03/main.c` using Q5.10 → float conversion
2. Reconstructs `wb2` (3×3), `wb3` (2×4), and `k` (2×4)
3. Runs the identical forward pass:
   ```matlab
   k_padded  = cat(1, k, ones(1,4))
   z2        = wb2 * k_padded
   a2        = sigmoid(z2)
   a2_padded = cat(1, a2, ones(1,4))
   z3        = wb3 * a2_padded
   a3        = sigmoid(z3)
   a3_rounded = round(a3)
   ```
4. Re-encodes `a3` back to Q5.10 and prints the expected `result0`/`result1` register values for waveform comparison

## Decoded matrix values (from firmware_test03)

```
wb2 = [ 1.369,  1.255, -19.881 ]
      [ 0.770,  0.970,  -0.900 ]
      [ 1.050,  0.640,  -0.891 ]

wb3 = [ 6.109, -1.311,  0.079, -2.591 ]
      [-7.101,  1.630,  1.970,  0.199 ]

k   = [ 8,  8,  5,  5 ]
      [ 8,  5,  8,  5 ]
```

Note: `wb3[0,0]` decodes to **6.109** (not 7.11) due to Q5.10 quantisation of the original `0x1870` constant.

## Usage

Run in MATLAB or Octave:
```matlab
tpu_matmul_verify
```

Compare the printed `result0`/`result1` hex values against the debug RAM locations in simulation:

| Address | Contents |
|---|---|
| `0x00001230` | result0 [31:0] |
| `0x00001234` | result0 [63:32] |
| `0x00001238` | result1 [31:0] |
| `0x0000123C` | result1 [63:32] |
