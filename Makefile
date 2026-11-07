PYTHON ?= python3
SIM ?= auto
JOBS ?= 4
BITSTREAM ?= build/artifacts/mimas_hdmi_top.bit

.PHONY: help project gui sim sim-vendor elaborate build program
help:
	@printf '%s\n' \
	  'make project     Create/update the generated Vivado project' \
	  'make gui         Open that project in Vivado' \
	  'make sim         Test the low-resolution EDID and DDC transactions' \
	  'make sim-vendor  Test HDMI forwarding/hot-plug with AMD I/O models' \
	  'make elaborate   Compile/elaborate the complete Artix-7 design' \
	  'make build       Run both simulations, implement, check timing/DRC, write .bit' \
	  'make program     Load the existing bitstream into SRAM using OpenOCD'

project:
	./scripts/vivado.sh -mode batch -source scripts/create_project.tcl

gui:
	./scripts/vivado.sh -mode gui -source scripts/create_project.tcl

sim:
	$(PYTHON) scripts/simulate.py --simulator $(SIM)

sim-vendor:
	$(PYTHON) scripts/simulate.py --vendor

elaborate:
	$(PYTHON) scripts/simulate.py --elaborate

build: sim sim-vendor
	./scripts/vivado.sh -mode batch -source scripts/build.tcl -tclargs $(JOBS)

# Load the existing artifact; rebuilding is a separate action.
program:
	$(PYTHON) scripts/program.py --bitstream "$(BITSTREAM)"
