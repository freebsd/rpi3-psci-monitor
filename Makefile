.SUFFIXES: .S .o .elf .tmp .bin .dtbo

CC8=aarch64-none-elf-gcc
LD8=aarch64-none-elf-ld
OBJCOPY8=aarch64-none-elf-objcopy
OBJDUMP8=aarch64-none-elf-objdump -maarch64

all: psci

psci: pscimon.bin

clean :
	rm -f *.o *.out *.tmp *.bin *.elf *~

.S.o:
	$(CC8) -c $< -o $@

.c.o:
	$(CC8) -fno-builtin -c $< -o $@

.o.elf:
	$(LD8) --section-start=.text=0 $< -o $@

.elf.tmp:
	$(OBJCOPY8) $< -O binary $@

.tmp.bin:
	dd if=$< ibs=256 of=$@ conv=sync

pscimon.elf: pscimon.o fdtpatch.o
	$(LD8) --section-start=.text=0 ${.ALLSRC} -o $@
