# Decoded 720p checkpoint

This separate design receives the GPU's live 1280x720 60 Hz RGB video,
decodes TMDS to canonical 24-bit RGB plus DE/HSYNC/VSYNC, registers those
signals together for one pixel-clock cycle and re-encodes them for HDMI OUT.
A first switch-controlled effect paints a 64x64 green square in the top-left
corner while DIP switch DP0 (pin B21) is on (see below). The receiver re-registers video into a
global 74.25 MHz pixel clock. A dedicated transmitter PLL derives its own
74.25 MHz pixel and 371.25 MHz serializer clocks from that recovered clock.
The 100 MHz board oscillator generates the independent 200 MHz calibration
reference. No independent video oscillator or frame-rate conversion is used.

The TX wrapper sets `kClkSwap=true`: reversing the forwarded clock pattern
resolved the physical monitor's failure to lock, with normal RGB data polarity.
This was checked on the local Mimas/RTX 5070 Ti/AORUS setup.

The receiver owns the only IDELAYCTRL for this design. Unlike the direct
bypass, it trains the three data-lane IDELAYs and word/channel alignment.
Its input clock is decoded/recovered, not passed through an IDELAY.

## Build and program

```sh
make filter-sim
make filter-build
make program BITSTREAM=build/filter/artifacts/mimas_filter_top.bit
```

`make filter-build` runs the existing EDID regression, new pixel/EDID unit tests
and a transmitter serialization/reset regression before implementation. It writes a separate
project under `build/filter/project`, reports under `build/filter/reports`,
and artifacts under `build/filter/artifacts`. `make filter-project` opens
this project in Vivado. VHDL-2008 sources and SystemVerilog are compiled
together; all source dependencies are local and version-pinned.

The default `make build` and `make program` still select the original serial
passthrough. Programming only loads volatile SRAM; it does not write flash.

This EDID has a different product ID, advertises 720p60 as its only timing,
and has no VGA fallback or extension blocks. Select actual 1280x720, 60 Hz,
8-bit RGB output from the GPU. The FPGA does not scale a higher-resolution
input. KDE may treat this EDID as a new display and need mirroring enabled.

## DIP switch square

`rtl/square_overlay.sv` sits after the pixel register and adds one more
pixel-clock stage to RGB and timing alike. It counts active pixels/lines from
DE and VSYNC and replaces pixels with x < 64 and y < 64 by pure green while
enabled. DP0 is synchronized into the pixel clock with a two-flop chain and
only sampled on each VSYNC rising edge, so the square switches on whole frames
without tearing. Other pixels, blanking and syncs pass through unchanged.

DP0 reads low in its ON position on this board, so the top level passes
`!dip_sw0` as `enable` (confirmed on hardware 2026-11-07).



Upstream HPD is asserted after monitor presence and local reference readiness
are synchronized and stable for 100 ms. It does not depend on incoming clock
lock, which would deadlock sources that wait for HPD before transmitting.
EDID remains available during receiver acquisition. Receiver/serializer reset
bridges assert asynchronously and release on their destination clocks. The
pixel stage masks active video until the first positive VSYNC after recovery.
Losing the input clock may cause the monitor to lose signal while reacquiring.

HDMI OUT is held in reset until the receiver has been locked continuously for
500 ms (`TX_HOLD_CYCLES`, counted on the received pixel clock, so no new
clock crossing); any lock loss resets that domain and restarts the wait.
Before this, a freshly programmed board often left the AORUS on its DP input
until S3 was pressed. Programming blanks the link for about 18 s, so the GPU
re-detects the display and its output can start and stop while the transmitter
was already following it. S3 always recovered. The hold-off makes the monitor
see one clean start. `hdmi_status.py` reports `tx_enabled` and
`video_starts_since_config` (never reset, saturating at 127; 1 means one clean
start) to confirm.

S3 resets the complete experiment. Monitor disconnect drops upstream HPD and
releases DDC after input synchronization. Toggling DP0 never resets anything;
it only changes the overlay from the next frame.

## Verification

`python3 scripts/simulate_filter.py --unit` checks the 720p-only EDID/checksum,
pixel/color/timing registration, blanking, the square's
position/size and per-frame switch latching, startup mid-frame and asynchronous
reset. The existing `make sim` verifies the original EDID/DDC behavior too.

The default XSim transmitter regression generates changing pixel patterns and
checks every serialized RGB pixel with an independent TMDS decoder. It tests
complete short frames, 1280-pixel active lines, 40-pixel HSYNC pulses,
1650-pixel line periods, five-line VSYNC pulses and reset recovery. It keeps
the 74.25 MHz pixel/742.5 Mbit/s lane rates but uses four active rows and 30
blank rows to make the regression practical. Actual AMD PLL and OSERDES models
remain in the DUT. Vivado synthesizes the VHDL cores into Verilog functional
models before simulation; it does not substitute an ideal transmitter.

`python3 scripts/simulate_filter.py --loopback` adds the receiver, independent
behavioral TMDS input, unequal lane phases, HPD/DDC and disconnect checks.
`--full-frame` selects all 720 active rows and a full 1650x750 raster.
`--rtl` uses behavioral VHDL/VITAL models in a separate directory. These
extended tests are slow, particularly the receiver's 50 ms acquisition timeout
per failed search step. There are no forced lock signals or shortened
acquisition timeouts. The default regression does not claim full-frame receiver
qualification; the physical 720p measurements and live test cover that setup.

The routed build checks setup/hold timing, clock definitions, unconstrained
internal endpoints, DRC and clock-domain crossings. The old serial bypass
lane-delay matching check does not apply to this registered design. Dynamic
input-eye training and cable margin require the functional and physical tests;
the timing report does not establish an external cable eye margin.

The CDC report retains eight individually reviewed reset findings. CDC-10
identifies combined local reset/monitor/lock requests entering reset bridges;
assertion is intentionally asynchronous and release is synchronized. CDC-11
identifies lock/reset requests fanning out to multiple two-flop reset bridges,
including the source-clock resets of the three timeout-status synchronizers.
These carry reset state, not independently sampled payload bits. Their exact
rule/source/destination tuples are checked in `scripts/check_filter_cdc.py`;
any other warning or critical crossing fails the build. No whole video clock
domain is false-pathed. The physical S3 reset is bridged before control logic,
and the upstream SyncBase source-reset issue is patched locally.

Two read-only BSCANE2 scan registers expose status and measured input geometry.
Their asynchronous capture endpoints are explicitly excluded from functional
CDC/timing checks; they have no path back into the video logic. Run
`python3 scripts/hdmi_status.py` to read them. Repeated stable readings are
appropriate because capture is asynchronous. Expected 720p values are 1280
active pixels/line, 720 active rows, 921600 active pixels/frame, 1650 pixel
clocks/line, 1237500 pixel clocks/frame and 40 clocks/HSYNC pulse.

## Physical checkpoint

On the monitor's FPGA HDMI input, verify moving desktop content, fine text and
red/green/blue patches. Check for stable colors without speckles or flicker,
then press S3 and reconnect a cable to confirm reacquisition. Simulation and
routing alone cannot establish compatibility with the actual GPU/cable/monitor.

On 2026-11-07 the board measured all of those expected input values, with all
three lanes aligned. The user confirmed a live output with readable text and
normal colors after setting the TX clock inversion. No square/filter is enabled.
`make filter-build` passed the default EDID, pixel and transmitter simulations,
then routed with 1.249 ns worst setup slack, 0.033 ns worst hold slack and zero
DRC findings. The final bitstream's configuration payload is identical to the
hardware-confirmed image; file headers have different build timestamps.

## Recovery

Before implementation, the tested 720p bypass bitstream, routed checkpoint,
source files, reports, source commit and SHA-256 manifest were preserved in
`build/recovery/720p-working/`. Its bitstream SHA-256 is
`7937c38c14a659cd2b08c2ac739788203e337a4eb219aad94cde907f5a315617`.

```sh
make program BITSTREAM=build/recovery/720p-working/mimas_hdmi_top.bit
```

The earlier VGA recovery directory remains available too. Recovery binaries
are local ignored build artifacts; source history alone cannot recreate their
exact routing. See `vendor/digilent/README.md` for source revision and patches.

The working decoded pipeline, its source snapshot, reports and hash manifest
are saved separately at `build/recovery/decoded-720p-working/`:

```sh
make program BITSTREAM=build/recovery/decoded-720p-working/mimas_filter_top.bit
```
