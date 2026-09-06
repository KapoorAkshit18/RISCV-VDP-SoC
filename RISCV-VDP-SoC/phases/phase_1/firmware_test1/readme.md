# Phase 5 — RISC-V Firmware-Driven SoC Verification

## Progress So Far

### Phase 1 — RISC-V + RAM Integration

Verified the new RISC-V SoC using **software-driven testing** instead of manually driving the native bus.

```text
RISC-V CPU
    ↓
CPU Bus Adapter
    ↓
SoC Memory Interconnect
    ↓
SoC RAM
```

### Firmware Flow

```text
start.S + main.c
       ↓
     GCC
       ↓
 firmware.elf
       ↓
    objcopy
       ↓
 firmware.bin
       ↓
   makehex.py
       ↓
 firmware.hex
       ↓
 $readmemh()
       ↓
 RAM mem[]
```

## Firmware Files

### `start.S`

Startup/boot assembly.

* Initializes the stack pointer.
* Calls `main()`.
* Keeps the CPU running after `main()` returns.

Example flow:

```asm
la sp, stack_top
call main
j 1b
```

**Purpose:** Provides the CPU entry point before C code executes.

### `main.c`

Contains the actual software test.

```c
volatile unsigned int *ram_test =
    (volatile unsigned int *)0x00000100;

int main(void)
{
    *ram_test = 42;

    volatile unsigned int value = *ram_test;

    while (value != 42)
        ;

    return 0;
}
```

**Purpose:** Generates real CPU load/store transactions.

Test performed:

```text
Write 42 → address 0x100
Read 0x100
Check returned value == 42
```

### `linker.ld`

Defines where the compiled program is placed in the SoC memory.

```ld
MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 1024
}
```

**Purpose:** Maps program sections (`.text`, `.data`, `.bss`, etc.) into the 1-KB RAM used in Phase 1.

---

## RISC-V Commands Used

* Check compiler:

  ```bash
  riscv64-unknown-elf-gcc --version
  ```

* Compile firmware:

  ```bash
  riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 \
  -Os -ffreestanding -nostdlib \
  -T linker.ld -o firmware.elf start.S main.c
  ```

* Check ELF size:

  ```bash
  riscv64-unknown-elf-size firmware.elf
  ```

* ELF → binary:

  ```bash
  riscv64-unknown-elf-objcopy -O binary firmware.elf firmware.bin
  ```

* Binary → Verilog HEX:

  ```bash
  python3 ~/riscv_workshop_collaterals/firmware/makehex.py \
  firmware.bin 256 > firmware.hex
  ```

* Compile SoC:

  ```bash
  iverilog -g2012 -o sim.vvp \
  riscv/rtl/riscv.v \
  riscv/rtl/riscv_wrapper.sv \
  riscv/rtl/cpu_bus_adapter.v \
  riscv/rtl/soc_mem_interconnect.v \
  RAM/soc_ram.v \
  riscv/rtl/cpu_soc_ram_top.v \
  riscv/tb/directed/tb_top.sv
  ```

* Run:

  ```bash
  vvp sim.vvp
  ```

* View waveform:

  ```bash
  gtkwave cpu_soc_ram_top.vcd
  ```

## Verification Result

* ✅ Firmware compiled successfully
* ✅ HEX generated successfully
* ✅ Firmware loaded into RAM using `$readmemh`
* ✅ CPU fetched instructions from RAM
* ✅ RAM write/read verified
* ✅ `42 (0x2A)` successfully written and read
* ✅ GTKWave confirmed CPU → Adapter → Interconnect → RAM transaction

## Challenges — Very Short

* **Firmware initially missing:** incorrect working directory.
* **ELF not found:** compilation had not completed successfully.
* **HEX generation:** reused VSD `makehex.py`.
* **RAM sizing:** `DEPTH=256` → 256 words = 1 KB.
* **Hierarchy:** firmware loaded through `dut.u_ram.mem`.
* **Icarus:** required the actual `riscv.v` CPU source in the compile list.

## Next

### Full Peripheral Integration 


