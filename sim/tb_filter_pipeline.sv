`timescale 1ns/1ps
`default_nettype none

// Independent behavioral DVI source and output decoder. Neither uses the
// vendor encoder/decoder as its reference, so byte/bit-order errors are visible.
module tb_filter_pipeline #(
    parameter integer ACTIVE_LINES = 4
);
    localparam real BIT_NS = 1000.0 / 742.5;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, hpd = 0;
    wire hpa;
    reg source_enabled = 0, rx_clk = 0;
    reg [2:0] serial_data = 0;
    wire [2:0] rx_data;
    // Unequal cable/lane phases exercise the receiver's delay training.
    assign #0.150 rx_data[0] = serial_data[0];
    assign #0.370 rx_data[1] = serial_data[1];
    assign #0.590 rx_data[2] = serial_data[2];
    wire tx_clk_p, tx_clk_n;
    wire [2:0] tx_p, tx_n;
    reg scl = 1, master_sda_low = 0;
    tri1 sda;
    assign sda = master_sda_low ? 1'b0 : 1'bz;
    tri rx_cec, tx_cec, tx_scl, tx_sda;
    mimas_filter_top #(.HPD_DELAY_CYCLES(16)) dut (
        .CLK1(clk), .RESET(rst),
        .hdmi_rx_clk_p(rx_clk), .hdmi_rx_clk_n(~rx_clk),
        .hdmi_rx_p(rx_data), .hdmi_rx_n(~rx_data),
        .hdmi_rx_hpa(hpa), .hdmi_rx_scl(scl), .hdmi_rx_sda(sda), .hdmi_rx_cec(rx_cec),
        .hdmi_tx_hpd(hpd), .hdmi_tx_clk_p(tx_clk_p), .hdmi_tx_clk_n(tx_clk_n),
        .hdmi_tx_p(tx_p), .hdmi_tx_n(tx_n),
        .hdmi_tx_cec(tx_cec), .hdmi_tx_rscl(tx_scl), .hdmi_tx_rsda(tx_sda)
    );
    `include "ddc_tasks.svh"

    function automatic [9:0] control_word(input h, v);
        case ({v,h})
            0: control_word = 10'b1101010100;
            1: control_word = 10'b0010101011;
            2: control_word = 10'b0101010100;
            3: control_word = 10'b1010101011;
        endcase
    endfunction
    task automatic encode(input [7:0] value, input active, h, v,
                          inout integer disparity, output reg [9:0] word_out);
        reg [8:0] q;
        integer ones, balance, i;
        reg xnor_mode;
        begin
            if (!active) begin
                word_out = control_word(h,v);
                disparity = 0;
            end else begin
                ones = 0;
                for (i = 0; i < 8; i = i + 1) ones = ones + value[i];
                xnor_mode = (ones > 4) || (ones == 4 && !value[0]);
                q[0] = value[0];
                for (i = 1; i < 8; i = i + 1) q[i] = q[i-1] ^ value[i] ^ xnor_mode;
                q[8] = !xnor_mode;
                ones = 0;
                for (i = 0; i < 8; i = i + 1) ones = ones + q[i];
                balance = 2*ones - 8;
                if (disparity == 0 || balance == 0) begin
                    word_out = {!q[8], q[8], (q[8] ? q[7:0] : ~q[7:0])};
                    disparity = disparity + (q[8] ? balance : -balance);
                end else if ((disparity > 0 && balance > 0) || (disparity < 0 && balance < 0)) begin
                    word_out = {1'b1, q[8], ~q[7:0]};
                    disparity = disparity - balance + 2*q[8];
                end else begin
                    word_out = {1'b0, q[8], q[7:0]};
                    disparity = disparity + balance - 2*(!q[8]);
                end
            end
        end
    endtask
    function automatic [23:0] test_pixel(input integer x, y, frame_number);
        reg [7:0] r,g,b;
        begin
            r = x ^ frame_number;
            g = y;
            b = (x >> 3) ^ (y >> 2) ^ 8'ha5;
            test_pixel = {r,g,b};
        end
    endfunction
    integer sx = 0, sy = 0, sf = 0, bit_index;
    integer source_start_ps = 0;
    integer rd = 0, gd = 0, bd = 0;
    reg active, sh, sv;
    reg [23:0] source_rgb;
    reg [9:0] words [0:2];
    initial begin
        if ($value$plusargs("SOURCE_START_PS=%d", source_start_ps)) begin end
        wait (source_enabled);
        #(source_start_ps / 1000.0);
        forever begin
            active = sx < 1280 && sy < ACTIVE_LINES;
            sh = sx >= 1390 && sx < 1430;
            sv = sy >= ACTIVE_LINES+5 && sy < ACTIVE_LINES+10;
            source_rgb = test_pixel(sx,sy,sf);
            encode(source_rgb[7:0], active, sh, sv, bd, words[0]);
            encode(source_rgb[15:8], active, 0, 0, gd, words[1]);
            encode(source_rgb[23:16], active, 0, 0, rd, words[2]);
            for (bit_index = 0; bit_index < 10; bit_index = bit_index + 1) begin
                rx_clk = bit_index >= 5;
                serial_data = {words[2][bit_index], words[1][bit_index], words[0][bit_index]};
                #(BIT_NS);
            end
            sx = sx + 1;
            if (sx == 1650) begin
                sx = 0; sy = sy + 1;
                if (sy == ACTIVE_LINES+30) begin
                    sy = 0; sf = sf + 1;
                    $display("Source frame %0d, recovered clock lock=%b, DE=%b at %0t",sf,dut.pixel_locked,dut.rx_de,$time);
                end
            end
        end
    end
    wire [31:0] full_frames;
    tmds_monitor #(.ACTIVE_LINES(ACTIVE_LINES)) monitor (
        .rst(rst), .enabled(dut.pixel_locked), .tx_clk_p(tx_clk_p),
        .tx_p(tx_p), .tx_n(tx_n), .full_frames(full_frames)
    );
    reg [7:0] edid_value;
    initial begin
        #300; @(negedge clk); rst = 0;
        repeat (20) @(negedge clk);
        if (hpa !== 0) $fatal(1,"HPD asserted without monitor");
        hpd = 1;
        wait (hpa === 1);
        if (rx_clk !== 0 || dut.pixel_locked !== 0)
            $fatal(1,"Startup test requires no source clock before HPD");
        $display("HPD advertised successfully before any incoming video clock");
        source_enabled = 1;
        begin_read(0); i2c_read(edid_value, 0); i2c_stop();
        if (edid_value !== 0) $fatal(1,"Top-level EDID unavailable");
        wait (full_frames == 2);
        @(negedge clk); rst = 1;
        #1; if (hpa !== 0) $fatal(1,"Reset must drop HPD immediately");
        repeat (32) @(negedge clk); rst = 0;
        wait (hpa === 1);
        wait (full_frames == 3);
        @(negedge clk); hpd = 0;
        repeat (8) @(negedge clk);
        if (hpa !== 0 || sda !== 1) $fatal(1,"Disconnect did not release HPD/DDC");
        if ({rx_cec,tx_cec,tx_scl,tx_sda} !== 4'bzzzz) $fatal(1,"Unused controls driven");
        $display("FPGA_VIDEO_PASS filter-pipeline");
        $finish;
    end
    initial begin
        // Two acquisitions can each search 32 taps x 10 word positions with
        // the real 50 ms timeout. This extended test is intentionally optional.
        #(60.0e9);
        $fatal(1,"Decoded pipeline timeout: lock=%b rx_de=%b output frames=%0d",dut.pixel_locked,dut.rx_de,full_frames);
    end
endmodule
`default_nettype wire
