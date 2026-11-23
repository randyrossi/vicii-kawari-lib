# Builds the mailbox demo with both assemblers and tests the library.
#
#   make         assemble the demo: build/beebasm/demo.prg, build/ca65/demo.prg
#   make check   also require the two builds to be identical, and run the
#                demo's self-test in the Kawari VICE (headless, ~10 seconds)
#
# The library itself needs no building: projects include the sources in
# beebasm/ or ca65/ directly. See README.md.

BEEBASM ?= $(if $(wildcard ../../tools/beebasm-new/build/beebasm),../../tools/beebasm-new/build/beebasm,beebasm)
CA65 ?= ca65
LD65 ?= ld65
X64SC ?= ../../vicii-kawari-vice/src/x64sc
CA65FLAGS = -I ca65 -I example/ca65 --bin-include-dir build/ca65

.PHONY: all beebasm ca65 check clean
all: beebasm ca65

beebasm:
	mkdir -p build/beebasm
	$(BEEBASM) -i example/beebasm/demo-cpu.asm
	$(BEEBASM) -i example/beebasm/demo-host.asm

ca65:
	mkdir -p build/ca65
	$(CA65) $(CA65FLAGS) -o build/ca65/demo-cpu.o example/ca65/demo-cpu.s
	$(LD65) -t none -S 0x0200 -o build/ca65/demo-cpu.bin build/ca65/demo-cpu.o
	$(CA65) $(CA65FLAGS) -o build/ca65/demo-host.o example/ca65/demo-host.s
	$(LD65) -t none -S 0x07FF -o build/ca65/demo.prg build/ca65/demo-host.o

# The demo writes 0 to the debug cartridge on success and 16 + the number of
# the failed test otherwise; x64sc exits with that value (1 = cycle limit
# reached, meaning the program hung, e.g. waiting for the co-processor).
check: all
	cmp build/beebasm/demo-cpu.bin build/ca65/demo-cpu.bin
	cmp build/beebasm/demo.prg build/ca65/demo.prg
	cd build && SDL_RENDER_DRIVER=software SDL_VIDEODRIVER=dummy \
	  ../$(X64SC) -default -pal +sound -warp -debugcart -limitcycles 100000000 \
	  -autostartprgmode 1 -autostart beebasm/demo.prg > vice.log 2>&1; \
	  code=$$?; if [ $$code -ne 0 ]; then \
	    echo "mailbox self-test FAILED (x64sc exit code $$code, see build/vice.log)"; exit 1; fi
	@echo "mailbox self-test passed"

clean:
	rm -rf build
