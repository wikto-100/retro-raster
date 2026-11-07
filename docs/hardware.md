# Hardware

Numato Mimas A7 V3.0, Vivado part `xc7a50tfgg484-1`
(Numato ordering code `XC7A50T-1FGG484C`).

Use external 12 V power with P2 jumpered on pins 2-3. Check the adapter polarity
against the board marking. P2 pins 1-2 select USB power.

## HDMI pins

| Signal | HDMI IN pins | HDMI OUT pins | Standard |
| --- | --- | --- | --- |
| TMDS clock P / N | K4 / J4 | L3 / K3 | TMDS_33 |
| Blue P / N | K1 / J1 | B1 / A1 | TMDS_33 |
| Green P / N | M1 / L1 | E1 / D1 | TMDS_33 |
| Red P / N | P2 / N2 | G1 / F1 | TMDS_33 |
| HPD | G2 (output to GPU) | B2 (input from monitor) | LVCMOS33 |
| CEC / DDC SCL / DDC SDA | K2 / J2 / H2 | E2 / D2 / C2 | LVCMOS33 |

H4 is the 100 MHz board clock; M2 is the active-high S3 reset (both LVCMOS33).

These match [Numato's V3.0 XDC](https://numato.com/download/mimas-a7-v3-0-constraints-file/).
The [board manual](https://docs.numato.com/docs/mimas-artix-7-fpga-development-board-with-ddr-sdram-and-gigabit-ethernet/)
links to a [schematic labeled V3.1](https://docs.numato.com/wp-content/uploads/2018/06/MimasA7_V3.1_Sch.pdf).
Use the V3.0 XDC for this project's pin assignments.

## Signal path and handshake

Each TMDS pair goes through an `IBUFDS`, fixed `IDELAYE2`, and `OBUFDS`, including
the incoming clock. The clock lane uses general routing like the data lanes;
it is not put on a BUFG or regenerated. There is no video decoding or frame buffer.
The 100 MHz board clock runs the handshake and an MMCM that generates a 200 MHz
reference for `IDELAYCTRL`. That MMCM does not generate the video clock.
The delay controller is held in reset for 160 ns after reference-clock lock.
Upstream HPD waits for calibration readiness as well as monitor presence.
The board provides the external input termination; FPGA `DIFF_TERM` is disabled.
See [AMD's SelectIO guide, TMDS section](https://docs.amd.com/api/khub/documents/IbGcnPFe6eF19RHma_Y~IA/content).

The monitor's HPD is synchronized. After it remains high for 100 ms, the FPGA
asserts HPD toward the GPU and serves a read-only EDID at DDC address `0x50`.
Disconnect or S3 drops upstream HPD and releases SDA. DDC SDA is open drain;
the FPGA never drives it high. Monitor-side DDC and both CEC pins float.

The EDID advertises digital RGB, preferred 1280x720 at 60 Hz and a VGA fallback,
with no extension blocks. Its preferred timing is:

| Axis | Active | Front porch | Sync | Back porch | Total |
| --- | --- | --- | --- | --- | --- |
| Horizontal | 1280 | 110 | 40 | 220 | 1650 |
| Vertical | 720 | 5 | 5 | 20 | 750 |

Both 720p syncs are active high. The source pixel clock is 74.25 MHz and the
TMDS data rate is 742.5 Mbit/s per lane (about 1.347 ns per bit). VGA remains
available at 25.18 MHz (59.95 Hz) or established VGA's 25.175 MHz (59.94 Hz),
with 800x525 total and negative syncs. The FPGA forwards whichever the GPU
sends; it does not generate timing or change the resolution.

The AORUS FO32U2P [manual](https://download.gigabyte.com/FileList/Manual/AORUS_FO32U2P_FO32U2_FO27Q3_FO32U_FO27Q2_UM_English_20240417.pdf)
lists 640x480 at 60 Hz for both HDMI inputs.

The output is DVI-compatible video. No audio, HDR, VRR, HDCP, HDMI 2.1 FRL,
or high-resolution input conversion is implemented. The GPU's model does not
change this path's supported mode; its actual HDMI output timing matters.

The constraints bound input-to-output latency to 10 ns. Fixed input-delay taps
in `rtl/tmds_passthrough.sv` compensate for route differences on this pinout.
The calibrated tap step is about 78 ps at a 200 MHz reference. Rebuild and
recheck timing after changing the taps or signal path.

The build requires a maximum 0.330 ns delay spread (less than a quarter of the
720p bit time). It checks both edges and output polarities, including the
forwarded clock, for min and max delays at each Slow and Fast corner. Results
are in `build/reports/passthrough.rpt`. These checks cover FPGA routing;
physical GPU/cable/monitor testing is still required.

## 720p experiment, 2026-11-07

The 720p build passed EDID conformance, DDC simulation, 742.5 Mbit/s forwarding
simulation, calibration/reset/hot-plug checks, timing, and DRC. The worst routed
lane/edge delay spread was 0.292 ns against the 0.330 ns limit.

Loaded into SRAM on the local RTX 5070 Ti setup. The GPU read the new EDID
exactly and selected 1280x720 at 60 Hz. The user confirmed a clearer live image;
motion improved after matching the mirrored source to 60.00 Hz and replacing
the test's 16 ms animation timer with vsync pacing. This is a test of the local
setup, not a characterization of every cable, receiver, or operating condition.
