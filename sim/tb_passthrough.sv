`timescale 1ns/1ps
`default_nettype none

module tb_passthrough;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg hpd = 0;
    wire hpa;
    reg rx_clock = 0;
    always #6.734 rx_clock = ~rx_clock; // 720p source clock ~74.25 MHz
    reg [2:0] rx_data = 0;
    wire tx_clock_p, tx_clock_n;
    wire [2:0] tx_p, tx_n;
    reg scl = 1;
    reg master_sda_low = 0;
    tri1 sda;
    assign sda = master_sda_low ? 1'b0 : 1'bz;
    tri rx_cec, tx_cec, tx_scl, tx_sda;
    mimas_hdmi_top #(.HPD_DELAY_CYCLES(16)) dut (
        .CLK1(clk), .RESET(rst),
        .hdmi_rx_clk_p(rx_clock), .hdmi_rx_clk_n(~rx_clock),
        .hdmi_rx_p(rx_data), .hdmi_rx_n(~rx_data),
        .hdmi_rx_hpa(hpa), .hdmi_rx_scl(scl), .hdmi_rx_sda(sda), .hdmi_rx_cec(rx_cec),
        .hdmi_tx_hpd(hpd), .hdmi_tx_clk_p(tx_clock_p), .hdmi_tx_clk_n(tx_clock_n),
        .hdmi_tx_p(tx_p), .hdmi_tx_n(tx_n),
        .hdmi_tx_cec(tx_cec), .hdmi_tx_rscl(tx_scl), .hdmi_tx_rsda(tx_sda)
    );
    `include "ddc_tasks.svh"
    reg forwarding_done = 0;
    reg handshake_done = 0;
    reg check_forwarding = 0;
    integer bit_number, burst;
    wire [2:0] expected_data;
    wire expected_clock;
    // AMD's functional IDELAY model: 600 ps base delay + 78 ps per tap at
    // 200 MHz. Compare the whole stream, not just a held test word. Routed
    // path matching is checked separately by Vivado, including both corners.
    assign #(0.600 + 0.078*dut.forwarding.BLUE_TAPS) expected_data[0] = rx_data[0];
    assign #(0.600 + 0.078*dut.forwarding.GREEN_TAPS) expected_data[1] = rx_data[1];
    assign #(0.600 + 0.078*dut.forwarding.RED_TAPS) expected_data[2] = rx_data[2];
    assign #(0.600 + 0.078*dut.forwarding.CLOCK_TAPS) expected_clock = rx_clock;
    // Allow vendor nonblocking assignments to settle. An inertial 10 ps check
    // rejects delta-cycle races without hiding a lost 1.347 ns video bit.
    wire data_mismatch, clock_mismatch;
    assign #0.010 data_mismatch = (tx_p !== expected_data || tx_n !== ~expected_data);
    assign #0.010 clock_mismatch =
        (tx_clock_p !== expected_clock || tx_clock_n !== !expected_clock);
    always @(posedge data_mismatch)
        if (check_forwarding && dut.forwarding_ready)
            $fatal(1, "TMDS data mismatch: actual %b/%b expected %b/%b",
                tx_p, tx_n, expected_data, ~expected_data);
    always @(posedge clock_mismatch)
        if (check_forwarding && dut.forwarding_ready)
            $fatal(1, "TMDS source clock was not forwarded");
    reg [15:0] noise = 16'hbeef;
    initial begin
        #300; // beyond the AMD glbl startup interval
        wait (dut.forwarding_ready === 1'b1);
        #10;
        check_forwarding = 1;
        for (burst = 0; burst < 3; burst = burst + 1) begin
            for (bit_number = 0; bit_number < 10000; bit_number = bit_number + 1) begin
                noise = {noise[14:0], noise[15] ^ noise[13] ^ noise[12] ^ noise[10]};
                rx_data = noise[2:0];
                #1.347; // 742.5 Mbit/s; retain every bit through calibrated delays
            end
            #2;
            // Exercise new data after a full frame interval, covering the
            // reported appearance of an output that stops after its first frame.
            if (burst != 2) #20000000;
        end
        forwarding_done = 1;
    end
    reg [7:0] value;
    integer n;
    initial begin
        #300;
        @(negedge clk); rst = 0;
        repeat (20) @(negedge clk);
        if (hpa !== 0) $fatal(1, "GPU sees a monitor with HPD low");
        // Ignore DDC while no monitor is attached.
        i2c_start(); i2c_write(8'ha0, 0); i2c_stop();
        @(negedge clk); hpd = 1;
        repeat (8) @(negedge clk);
        if (hpa !== 0) $fatal(1, "HPD asserted before debounce interval");
        wait (dut.forwarding_ready === 1'b1);
        repeat (24) @(negedge clk);
        if (hpa !== 1) $fatal(1, "Monitor connection did not reach GPU");
        begin_read(0);
        for (n = 0; n < 8; n = n + 1) begin
            i2c_read(value, n != 7);
            if (value !== ((n == 0 || n == 7) ? 8'h00 : 8'hff))
                $fatal(1, "GPU could not read EDID through top-level SDA");
        end
        i2c_stop();
        @(negedge clk); hpd = 0;
        repeat (4) @(negedge clk);
        if (hpa !== 0 || sda !== 1) $fatal(1, "Monitor disconnect did not release GPU/DDC");
        @(negedge clk); hpd = 1;
        repeat (24) @(negedge clk);
        if (hpa !== 1) $fatal(1, "Monitor reconnect failed");
        @(negedge clk); rst = 1;
        #1;
        if (hpa !== 0) $fatal(1, "Reset did not immediately drop upstream HPD");
        repeat (4) @(negedge clk);
        rst = 0;
        repeat (8) @(negedge clk);
        if (hpa !== 0) $fatal(1, "Reset bypassed HPD debounce");
        wait (dut.forwarding_ready === 1'b1);
        repeat (24) @(negedge clk);
        if (hpa !== 1) $fatal(1, "Reset recovery failed");
        if ({rx_cec, tx_cec, tx_scl, tx_sda} !== 4'bzzzz)
            $fatal(1, "Unused control pins are being driven");
        handshake_done = 1;
    end
    initial begin
        wait (forwarding_done && handshake_done);
        $display("FPGA_VIDEO_PASS passthrough");
        $finish;
    end
    initial begin
        #60000000;
        $fatal(1, "passthrough test timeout");
    end
endmodule

`default_nettype wire
