# Firmware Test 05 — MATLAB Network on TPU

Implements the following MATLAB forward pass on the RISC-V TPU peripheral.

## MATLAB Reference

```matlab
k = [8, 8, 5, 5;
     8, 5, 8, 5]

wb2 = [1.37,  1.37, -19.88;
       0.77,  0.97,  -0.90;
       1.05,  0.64,  -0.89]

wb3 = [ 7.11, -1.31,  0.08, -2.59;
       -7.10,  1.63,  1.97,  0.20]

k_padded  = cat(1, k, ones(1, 4))
z2        = wb2 * k_padded
a2        = 1./(1+exp(-z2))
a2_padded = cat(1, a2, ones(1, 4))
z3        = wb3 * a2_padded
a3        = 1./(1+exp(-z3))
a3_rounded = round(a3)
```

## Network Topology

```
Input k (2x4)
      |
  [bias append -> k_padded 3x4]
      |
  wb2 (3x3) * k_padded -> z2 (3x4)
      |
  sigmoid -> a2 (3x4)
      |
  [bias append -> a2_padded 4x4]
      |
  wb3 (2x4) * a2_padded -> z3 (2x4)
      |
  sigmoid -> a3 (2x4)
      |
  round -> a3_rounded (2x4)
```

The bias rows (ones) in k_padded and a2_padded are absorbed into the weight
matrix last columns: wb2 col2 acts as the layer-2 bias, wb3 col3 acts as the
layer-3 bias.

## Fixed-Point Format: Q5.10

- 16-bit signed: 1 sign + 5 integer + 10 fractional bits
- Encoding: `int16 = round(float * 1024)`
- Range: approximately -32.0 to +31.999

## AXI-Stream Beat / Register Mapping

| Register | Beat | Contents              | Q5.10 hex                  |
|----------|------|-----------------------|----------------------------|
| weight0  |  0   | wb2 row0              | `0x0000_B07B_057B_057B`    |
| weight1  |  1   | wb2 row1              | `0x0000_FC66_03E2_0315`    |
| weight2  |  2   | wb2 row2              | `0x0000_FC70_028F_0433`    |
| weight3  |  3   | wb3 row0              | `0xF5A4_0052_FAC2_1C71`    |
| weight4  |  4   | wb3 row1              | `0x00CD_07E1_0685_E31A`    |
| input0   |  5   | k row0: 8,8,5,5       | `0x1400_1400_2000_2000`    |
| input1   |  6   | k row1: 8,5,8,5+TLAST | `0x1400_2000_1400_2000`    |

## Expected Output

```
a3[0]         = [0.9933, 0.0003, 0.9933, 0.0003]
a3[1]         = [0.0067, 0.9997, 0.0067, 0.9997]

a3_rounded[0] = [1, 0, 1, 0]
a3_rounded[1] = [0, 1, 0, 1]
```

result0 (Q5.10) holds a3 row0, result1 holds a3 row1.
Each 64-bit result packs 4 x 16-bit Q5.10 values: bits[15:0]=col0 ... bits[63:48]=col3.

## Debug RAM Locations

| Address      | Contents          |
|--------------|-------------------|
| `0x00001230` | result0 [31:0]    |
| `0x00001234` | result0 [63:32]   |
| `0x00001238` | result1 [31:0]    |
| `0x0000123C` | result1 [63:32]   |
| `0x000012A0` | elapsed cycles lo |
| `0x000012A4` | elapsed cycles hi |
| `0x000012A8` | marker            |

Marker values: `0x11111111`=START, `0x22222222`=DONE, `0x33333333`=SUCCESS, `0xDEAD0001`=ERROR

## Build

```bash
make
```

Requires `riscv32-unknown-elf-gcc` on PATH.
