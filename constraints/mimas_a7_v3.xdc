# Numato Mimas A7 V3.0, xc7a50tfgg484-1. See docs/hardware.md for provenance.
# Only pins used by this design are included; do not add the entire master XDC.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullnone [current_design]

set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS33} [get_ports CLK1]
set_property -dict {PACKAGE_PIN M2 IOSTANDARD LVCMOS33} [get_ports RESET]
# DIP switches DP0-DP7 (Numato's Mimas A7 master XDC).
set_property -dict {PACKAGE_PIN B21 IOSTANDARD LVCMOS33} [get_ports {dip_sw[0]}]
set_property -dict {PACKAGE_PIN A21 IOSTANDARD LVCMOS33} [get_ports {dip_sw[1]}]
set_property -dict {PACKAGE_PIN E22 IOSTANDARD LVCMOS33} [get_ports {dip_sw[2]}]
set_property -dict {PACKAGE_PIN D22 IOSTANDARD LVCMOS33} [get_ports {dip_sw[3]}]
set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVCMOS33} [get_ports {dip_sw[4]}]
set_property -dict {PACKAGE_PIN D21 IOSTANDARD LVCMOS33} [get_ports {dip_sw[5]}]
set_property -dict {PACKAGE_PIN G21 IOSTANDARD LVCMOS33} [get_ports {dip_sw[6]}]
set_property -dict {PACKAGE_PIN G22 IOSTANDARD LVCMOS33} [get_ports {dip_sw[7]}]
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

# Fixed 720p recovered clock; the receiver MMCM/BUFR derive 5x and 1x clocks.
create_clock -name hdmi_pixel_in -period 13.468 [get_ports hdmi_rx_clk_p]

# Only this receiver owns the delay resources in bank 35.
set_property IODELAY_GROUP rx_delay [get_cells -hier -filter {REF_NAME == IDELAYE2 || REF_NAME == IDELAYCTRL}]

# Port CDC: asynchronous switches/DDC are sampled by dedicated input chains.
set_false_path -from [get_ports RESET]
set_false_path -from [get_ports {dip_sw[*]}] -to [get_cells -hier -filter {NAME =~ filters/enable_sync0_reg*}]
set_false_path -from [get_ports hdmi_tx_hpd] -to [get_cells -hier -filter {NAME =~ hpd_sync_reg*}]
set_false_path -from [get_ports {hdmi_rx_scl hdmi_rx_sda}] -to [get_cells -hier -filter {NAME =~ edid/*sync_reg*}]
set_false_path -to [get_ports {hdmi_rx_sda hdmi_rx_hpa}]

# Upstream CDC boundaries: cut the first synchronizer stage and asynchronous
# bridge resets, never the registered RGB/timing path.
set_false_path -to [get_pins -hier -regexp {.*SyncAsync.*/oSyncStages_reg\[0\]/D}]
set_false_path -to [get_pins -hier -filter {NAME =~ */*SyncAsync*/* && (REF_PIN_NAME == PRE || REF_PIN_NAME == CLR)}]
set_false_path -to [get_pins -hier -filter {NAME =~ */*SyncBase*/iIn_q_reg/* && (REF_PIN_NAME == PRE || REF_PIN_NAME == CLR)}]
set_false_path -to [get_pins -hier -filter {NAME =~ video_reset_sync_reg*/* && (REF_PIN_NAME == PRE || REF_PIN_NAME == CLR)}]
set_false_path -to [get_pins -hier -filter {NAME =~ control_reset_sync_reg*/* && (REF_PIN_NAME == PRE || REF_PIN_NAME == CLR)}]


