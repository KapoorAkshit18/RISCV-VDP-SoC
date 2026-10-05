CROSS   = riscv32-unknown-elf
CC      = $(CROSS)-gcc
OBJCOPY = $(CROSS)-objcopy
OBJDUMP = $(CROSS)-objdump

CFLAGS  = -march=rv32i -mabi=ilp32 -O2 -Wall \
          -ffreestanding -nostdlib -nostartfiles

TARGET  = firmware

all: $(TARGET).hex $(TARGET).bin $(TARGET).dump

$(TARGET).elf: start.S main.c linker.ld
	$(CC) $(CFLAGS) -T linker.ld -o $@ start.S main.c

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O verilog $< $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -d $< > $@

clean:
	rm -f $(TARGET).elf $(TARGET).hex $(TARGET).bin $(TARGET).dump
