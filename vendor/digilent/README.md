# Digilent video cores

dvi2rgb and rgb2dvi from https://github.com/Digilent/vivado-library at
`0362ce72d39eebc400fdabacff706ee7fa8ad564`. BSD-3-Clause. File origins are in
`upstream.json`.

Local changes:

- TMDS_Clocking.vhd: input period 13.468 ns.
- ChannelBond.vhd, PhaseAlign.vhd: explicit counter wrap.
- SyncBase.vhd: reset synchronized to the source clock.
- dvi2rgb.vhd: lane status output. LF line endings.
