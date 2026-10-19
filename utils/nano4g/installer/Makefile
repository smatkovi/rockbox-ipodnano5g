CROSS ?= arm-none-eabi-
PYTHON ?= python3
HOSTCC ?= cc
NAND = ../../../firmware/target/arm/s5l8702/ipodnano4g
CC = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy
CFLAGS = -mcpu=arm1176jz-s -marm -mno-unaligned-access -Os -std=c99 \
         -ffreestanding -fno-builtin -fno-stack-protector -fno-unwind-tables \
         -fno-asynchronous-unwind-tables -ffunction-sections -fdata-sections \
         -Wall -Wextra -Werror -I$(NAND) -Ibuild
OBJECTS = build/entry.o build/support.o build/flash.o build/usb.o build/aes.o \
          build/lcd.o build/main.o
STARTUP = ../../../bootloader/nano4g-startup

.PHONY: all clean
all: build/installer-native.bin

build:
	mkdir -p $@
FMSS_SRC = $(NAND)/fmss/reset.s $(NAND)/fmss/readid.s \
           fmss/boot_read.s fmss/boot_program.s fmss/erase.s

build/fmssasm: ../../../tools/fmssasm.c | build
	$(HOSTCC) -O -Wall -Wextra $< -o $@
build/fmss-installer.h: $(FMSS_SRC) build/fmssasm
	build/fmssasm -s $@ $(FMSS_SRC)
build/flash.o: build/fmss-installer.h $(NAND)/nand-chip-table.h $(NAND)/nand-target.h
build/main.o build/lcd.o build/usb.o: console.h
build/%.o: %.c hardware.h | build
	$(CC) $(CFLAGS) -c $< -o $@
build/entry.o: entry.S | build
	$(CC) $(CFLAGS) -c $< -o $@
build/installer.elf: $(OBJECTS) installer.lds
	$(CC) $(CFLAGS) -nostdlib -Wl,--gc-sections,-z,noexecstack,-T,installer.lds \
	    $(OBJECTS) -lgcc -o $@
build/installer.bin: build/installer.elf
	$(OBJCOPY) -O binary $< $@
build/installer-native.bin: build/installer.bin ../boot/build_payload.py \
                           $(STARTUP)/entry.S $(STARTUP)/early-init.c \
                           $(STARTUP)/early-init.h $(STARTUP)/startup.lds
	rm -f $@
	$(PYTHON) ../boot/build_payload.py $< $@ --toolchain $(CROSS)
clean:
	rm -rf build
