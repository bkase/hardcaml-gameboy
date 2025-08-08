# Makefile for building GameBoy ROMs

.PHONY: all clean

all: flat_bg.gb

flat_bg.gb: flat_bg.asm
	rgbasm -o flat_bg.o flat_bg.asm
	rgblink -o flat_bg.gb flat_bg.o
	rgbfix -p 0xFF -v flat_bg.gb

clean:
	rm -f *.o *.gb