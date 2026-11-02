# Numato Mimas A7 V3.0, xc7a50tfgg484-1. See docs/hardware.md for provenance.
# Only pins used by this design are included; do not add the entire master XDC.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullnone [current_design]

set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS33} [get_ports CLK1]
set_property -dict {PACKAGE_PIN M2 IOSTANDARD LVCMOS33} [get_ports RESET]
create_clock -name clk_100mhz -period 10.000 [get_ports CLK1]

set_property -dict {PACKAGE_PIN L3 IOSTANDARD TMDS_33} [get_ports hdmi_tx_clk_p]
set_property -dict {PACKAGE_PIN K3 IOSTANDARD TMDS_33} [get_ports hdmi_tx_clk_n]
set_property -dict {PACKAGE_PIN B1 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_p[0]}]
set_property -dict {PACKAGE_PIN A1 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_n[0]}]
set_property -dict {PACKAGE_PIN E1 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_p[1]}]
set_property -dict {PACKAGE_PIN D1 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_n[1]}]
set_property -dict {PACKAGE_PIN G1 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_p[2]}]
set_property -dict {PACKAGE_PIN F1 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_n[2]}]
set_property -dict {PACKAGE_PIN B2 IOSTANDARD LVCMOS33} [get_ports hdmi_tx_hpd]
set_property -dict {PACKAGE_PIN E2 IOSTANDARD LVCMOS33} [get_ports hdmi_tx_cec]
set_property -dict {PACKAGE_PIN D2 IOSTANDARD LVCMOS33} [get_ports hdmi_tx_rscl]
set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS33} [get_ports hdmi_tx_rsda]

# External reset is asynchronous; HPD is consumed only by its two-flop synchronizer.
set_false_path -from [get_ports RESET]
set_false_path -from [get_ports hdmi_tx_hpd]
# MMCM output clocks are automatically derived. Keep pixel/serial clocks related.
