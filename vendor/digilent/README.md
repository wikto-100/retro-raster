# Digilent video cores

Source: https://github.com/Digilent/vivado-library

Pinned revision: `0362ce72d39eebc400fdabacff706ee7fa8ad564`.

This is a source subset of dvi2rgb and rgb2dvi, licensed under BSD-3-Clause.
Original copyright/license headers are preserved. Shared DVI_Constants,
SyncAsync and ResetBridge sources are identical in the two upstream cores and
are compiled once from common/. upstream.json records original paths and Git
blob IDs; no build-time network access is required.

The wrappers in rtl/ configure 7-series TMDS I/O for 720p60, disable debug and
DDC emulation, re-register into the receiver's global pixel clock and use a
dedicated transmitter PLL driven by that recovered clock. The TX wrapper sets
kClkSwap=true; this clock phase produced a normal live picture on the tested
Mimas/monitor setup. RGB lane polarities are unchanged.
Both upstream video ports use RBG packing; wrappers expose canonical RGB.
The upstream XDC files are retained for reference; the project uses the scoped
adaptation in constraints/mimas_a7_v3.xdc, not the upstream OOC clocks.
The optional DDC and internal MMCM transmitter branch are disabled. The
receiver's global pixel resynchronization and transmitter PLL are enabled.
No ILA/generated IP or EDID data files are needed.

Local changes to upstream VHDL:

- TMDS_Clocking.vhd: input clock period set to 13.468013468 ns for this fixed
  74.25 MHz receiver configuration.
- ChannelBond.vhd: explicitly wrap the two 32-entry FIFO addresses. This
  preserves synthesized 5-bit wrap behavior in bounds-checked simulation.
- PhaseAlign.vhd: explicitly wrap the 128-token counter and two-bit delay wait
  counter; widen the latter's declared range to include the existing hardware
  overflow value. No shortened acquisition timeout or simulation bypass.
- SyncBase.vhd: bridge asynchronous reset into the source clock before releasing
  the source register. Its reset previously came from the other clock domain.
- dvi2rgb.vhd: expose read-only lane alignment/calibration status (unused by
  the top level). Source line endings are normalized to LF.

