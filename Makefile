JOBS ?= 4
BITSTREAM ?= build/retro_raster.bit

.PHONY: sim build gui program
sim:
	python3 scripts/simulate.py

build: sim
	./scripts/vivado.sh -mode batch -source scripts/build.tcl -tclargs $(JOBS)

gui:
	./scripts/vivado.sh -mode gui -source scripts/project.tcl

# Load into SRAM only (volatile); does not rebuild or write flash.
program:
	python3 scripts/program.py --bitstream "$(BITSTREAM)"
