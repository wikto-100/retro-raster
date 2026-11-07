# Ordered VHDL dependencies, shared with the mixed-language simulation runner.
set filter_vhdl_relative {
    vendor/digilent/common/DVI_Constants.vhd
    vendor/digilent/common/SyncAsync.vhd
    vendor/digilent/common/SyncAsyncReset.vhd
    vendor/digilent/dvi2rgb/SyncBase.vhd
    vendor/digilent/dvi2rgb/GlitchFilter.vhd
    vendor/digilent/dvi2rgb/TWI_SlaveCtl.vhd
    vendor/digilent/dvi2rgb/EEPROM_8b.vhd
    vendor/digilent/dvi2rgb/InputSERDES.vhd
    vendor/digilent/dvi2rgb/PhaseAlign.vhd
    vendor/digilent/dvi2rgb/ChannelBond.vhd
    vendor/digilent/dvi2rgb/TMDS_Decoder.vhd
    vendor/digilent/dvi2rgb/TMDS_Clocking.vhd
    vendor/digilent/dvi2rgb/ResyncToBUFG.vhd
    vendor/digilent/dvi2rgb/dvi2rgb.vhd
    vendor/digilent/rgb2dvi/ClockGen.vhd
    vendor/digilent/rgb2dvi/OutputSERDES.vhd
    vendor/digilent/rgb2dvi/TMDS_Encoder.vhd
    vendor/digilent/rgb2dvi/rgb2dvi.vhd
    rtl/hdmi_rx.vhd
    rtl/hdmi_tx.vhd
}
set filter_sv_relative {
    rtl/edid_slave.sv
    rtl/video_register.sv
    rtl/square_overlay.sv
    rtl/hdmi_debug.sv
    rtl/video_probe.sv
    rtl/mimas_filter_top.sv
}
