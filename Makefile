# make sim / build / gui / program. Run from the repository root.
JOBS ?= 4
BITSTREAM ?= build/retro_raster.bit

.PHONY: sim build gui program
sim:
	python3 scripts/simulate.py

build: sim
	./scripts/vivado.sh -mode batch -source scripts/build.tcl -tclargs $(JOBS)

gui:
	./scripts/vivado.sh -mode gui -source scripts/project.tcl

# Load the bitstream into the FPGA. It is lost on power-off.
program:
	python3 scripts/program.py --bitstream "$(BITSTREAM)"
