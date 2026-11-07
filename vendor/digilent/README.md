# Digilent video cores

Subset of dvi2rgb and rgb2dvi from https://github.com/Digilent/vivado-library
at revision `0362ce72d39eebc400fdabacff706ee7fa8ad564`, BSD-3-Clause (see
`LICENSE`). `upstream.json` records each file's upstream path and Git blob.
The wrappers in `rtl/` expose canonical RGB (upstream packs RBG).

Local changes:

- TMDS_Clocking.vhd: input clock period fixed at 13.468 ns (74.25 MHz).
- ChannelBond.vhd, PhaseAlign.vhd: explicit counter wrap, matching the
  synthesized behavior in bounds-checked simulation.
- SyncBase.vhd: bridge the asynchronous reset into the source clock.
- dvi2rgb.vhd: expose lane alignment status (unused). Line endings are LF.
