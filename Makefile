.SUFFIXES: .S .o .elf -gic.elf .tmp -gic.tmp .bin -gic.bin .dtbo -gic.o

CC8=aarch64-none-elf-gcc
LD8=aarch64-none-elf-ld
OBJCOPY8=aarch64-none-elf-objcopy
OBJDUMP8=aarch64-none-elf-objdump -maarch64

all: armstub8.bin armstub8-gic.bin

clean :
	rm -f *.o *.out *.tmp *.bin *.elf *~

.S.o:
	$(CC8) -c $< -o $@

.S-gic.o:
	$(CC8) -DGIC -c $< -o $@

.c.o:
	$(CC8) -fno-builtin -c $< -o $@

.c-gic.o:
	$(CC8) -DGIC -fno-builtin -c $< -o $@

.o.elf:
	$(LD8) --section-start=.text=0 $< -o $@

-gic.o-gic.elf:
	$(LD8) --section-start=.text=0 $< -o $@

.elf.tmp:
	$(OBJCOPY8) $< -O binary $@

-gic.elf-gic.tmp:
	$(OBJCOPY8) $< -O binary $@

.tmp.bin:
	dd if=$< ibs=256 of=$@ conv=sync

-gic.tmp-gic.bin:
	dd if=$< ibs=256 of=$@ conv=sync

armstub8.elf: pscimon.o fdtpatch.o
	$(LD8) --section-start=.text=0 ${.ALLSRC} -o $@

armstub8-gic.elf: pscimon-gic.o fdtpatch-gic.o
	$(LD8) --section-start=.text=0 ${.ALLSRC} -o $@
