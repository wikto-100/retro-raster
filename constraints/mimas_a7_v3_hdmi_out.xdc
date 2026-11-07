# Numato Mimas A7 V3.0, xc7a50tfgg484-1. See docs/hardware.md for provenance.
# Only pins used by this design are included; do not add the entire master XDC.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullnone [current_design]

set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS33} [get_ports CLK1]
set_property -dict {PACKAGE_PIN M2 IOSTANDARD LVCMOS33} [get_ports RESET]
create_clock -name clk_100mhz -period 10.000 [get_ports CLK1]

set_property -dict {PACKAGE_PIN K4 IOSTANDARD TMDS_33} [get_ports hdmi_rx_clk_p]
set_property -dict {PACKAGE_PIN J4 IOSTANDARD TMDS_33} [get_ports hdmi_rx_clk_n]
set_property -dict {PACKAGE_PIN K1 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_p[0]}]
set_property -dict {PACKAGE_PIN J1 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_n[0]}]
set_property -dict {PACKAGE_PIN M1 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_p[1]}]
set_property -dict {PACKAGE_PIN L1 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_n[1]}]
set_property -dict {PACKAGE_PIN P2 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_p[2]}]
set_property -dict {PACKAGE_PIN N2 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_n[2]}]
set_property -dict {PACKAGE_PIN G2 IOSTANDARD LVCMOS33} [get_ports hdmi_rx_hpa]
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports hdmi_rx_scl]
set_property -dict {PACKAGE_PIN H2 IOSTANDARD LVCMOS33} [get_ports hdmi_rx_sda]
set_property -dict {PACKAGE_PIN K2 IOSTANDARD LVCMOS33} [get_ports hdmi_rx_cec]

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

# The four TMDS pairs are asynchronous combinational input-to-output paths.
# Calibrated IDELAYs match their routes. Bound latency; build.tcl checks their
# relative delays at both corners and edges to a quarter of the 720p bit time.
# Never false-path these lanes or infer a BUFG on the incoming clock lane.
set tmds_inputs [get_ports {hdmi_rx_clk_p hdmi_rx_clk_n hdmi_rx_p[*] hdmi_rx_n[*]}]
set tmds_outputs [get_ports {hdmi_tx_clk_p hdmi_tx_clk_n hdmi_tx_p[*] hdmi_tx_n[*]}]
set_max_delay 10.000 -datapath_only -from $tmds_inputs -to $tmds_outputs
set_min_delay 0.000 -from $tmds_inputs -to $tmds_outputs

# DDC and monitor HPD are synchronized at 100 MHz; S3 is the external reset.
set_false_path -from [get_ports RESET]
set_false_path -from [get_ports hdmi_tx_hpd]
set_false_path -from [get_ports {hdmi_rx_scl hdmi_rx_sda}]
# Slow asynchronous control outputs (100 kHz open-drain DDC and hot-plug).
set_false_path -to [get_ports {hdmi_rx_sda hdmi_rx_hpa}]
