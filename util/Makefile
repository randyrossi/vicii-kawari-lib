# Builds the utility library's demo with both assemblers and tests it.
#
#   make         assemble the demo: build/beebasm/demo.prg, build/ca65/demo.prg
#   make check   also require the two builds to be identical, and run the
#                demo headless in the Kawari VICE (must report firmware 1.20
#                or later) and, if STOCK_X64SC exists, in a VICE without
#                Kawari (must report that there is none)
#
# The library itself needs no building: projects include the sources in
# beebasm/ or ca65/ directly. See README.md.

BEEBASM ?= $(if $(wildcard ../../tools/beebasm-new/build/beebasm),../../tools/beebasm-new/build/beebasm,beebasm)
CA65 ?= ca65
LD65 ?= ld65
X64SC ?= $(abspath ../../vicii-kawari-vice/src/x64sc)
STOCK_X64SC ?= /usr/bin/x64sc
RUN = cd build && SDL_RENDER_DRIVER=software SDL_VIDEODRIVER=dummy
VICEFLAGS = -default -pal +sound -warp -debugcart -limitcycles 100000000 \
  -autostartprgmode 1 -autostart beebasm/demo.prg

.PHONY: all beebasm ca65 check clean
all: beebasm ca65

beebasm:
	mkdir -p build/beebasm
	$(BEEBASM) -i example/beebasm/demo.asm

ca65:
	mkdir -p build/ca65
	$(CA65) -I ca65 -o build/ca65/demo.o example/ca65/demo.s
	$(LD65) -t none -S 0x07FF -o build/ca65/demo.prg build/ca65/demo.o

# x64sc exits with the value the demo writes to the debug cartridge: 0 = a
# Kawari with firmware 1.20 or later, 2 = older firmware, 3 = no Kawari,
# 16 + n = library check n failed (1 = cycle limit reached: it hung).
check: all
	cmp build/beebasm/demo.prg build/ca65/demo.prg
	$(RUN) $(X64SC) $(VICEFLAGS) > vice.log 2>&1; code=$$?; \
	  if [ $$code -ne 0 ]; then \
	    echo "util self-test FAILED in Kawari VICE (exit code $$code, see build/vice.log)"; exit 1; fi
	@if [ -x $(STOCK_X64SC) ]; then \
	  $(RUN) $(STOCK_X64SC) $(VICEFLAGS) > vice-stock.log 2>&1; code=$$?; \
	  if [ $$code -ne 3 ]; then \
	    echo "util self-test FAILED in stock VICE (exit code $$code, expected 3, see build/vice-stock.log)"; exit 1; fi; \
	else echo "no stock x64sc at $(STOCK_X64SC): no-Kawari case not tested"; fi
	@echo "util self-test passed"

clean:
	rm -rf build
