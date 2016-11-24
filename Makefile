BINS=pscimon.bin

CC8=aarch64-none-elf-gcc
LD8=aarch64-none-elf-ld
OBJCOPY8=aarch64-none-elf-objcopy
OBJDUMP8=aarch64-none-elf-objdump -maarch64

all : $(BINS)

clean :
	rm -f *.o *.out *.tmp *.bin *.ds *.C armstubs.h bin2c *~

%.o: %.S
	$(CC8) -c $< -o $@

%.elf: %.o
	$(LD8) --section-start=.text=0 $< -o $@

%.tmp: %.elf
	$(OBJCOPY8) $< -O binary $@

%.bin: %.tmp
	dd if=$< ibs=256 of=$@ conv=sync
