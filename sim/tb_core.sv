`timescale 1ns/1ps
`default_nettype none

module tb_core;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg scl = 1;
    reg master_sda_low = 0;
    tri1 sda;
    wire slave_sda_low;
    assign sda = (master_sda_low || slave_sda_low) ? 1'b0 : 1'bz;
    edid_slave dut (.clk(clk), .rst(rst), .scl(scl), .sda(sda), .sda_low(slave_sda_low));
    `include "ddc_tasks.svh"
    reg [7:0] block_data [0:127];
    reg [7:0] value;
    integer n, checksum;
    initial begin
        repeat (5) @(negedge clk);
        rst = 0;
        begin_read(0);
        checksum = 0;
        for (n = 0; n < 128; n = n + 1) begin
            i2c_read(block_data[n], n != 127);
            if ((^block_data[n]) === 1'bx) $fatal(1, "Unknown EDID byte %0d", n);
            checksum = checksum + block_data[n];
        end
        i2c_stop();
        if ((checksum & 255) != 0) $fatal(1, "Bad EDID checksum");
        if ({block_data[0], block_data[1], block_data[2], block_data[3],
             block_data[4], block_data[5], block_data[6], block_data[7]} !== 64'h00ffffffffffff00)
            $fatal(1, "Bad EDID header");
        if (block_data[18] != 1 || block_data[19] != 3 || !block_data[20][7])
            $fatal(1, "EDID must identify a digital display");
        if (block_data[35] != 8'h20 || block_data[36] != 0 || block_data[37] != 0)
            $fatal(1, "EDID advertises additional established modes");
        for (n = 38; n < 54; n = n + 1)
            if (block_data[n] != 1) $fatal(1, "EDID advertises additional standard modes");
        if ({block_data[58][7:4], block_data[56]} != 1280 ||
            {block_data[61][7:4], block_data[59]} != 720 ||
            {block_data[58][3:0], block_data[57]} != 370 ||
            {block_data[61][3:0], block_data[60]} != 30 ||
            {block_data[55], block_data[54]} != 7425 || block_data[71] != 8'h1e ||
            block_data[62] != 110 || block_data[63] != 40 || block_data[64] != 8'h55)
            $fatal(1, "Preferred timing is not 1280x720 60 Hz");
        if ({block_data[76][7:4], block_data[74]} != 640 ||
            {block_data[79][7:4], block_data[77]} != 480 ||
            {block_data[73], block_data[72]} != 2518 || block_data[89] != 8'h18)
            $fatal(1, "VGA fallback detailed timing missing");
        if (block_data[113] != 59 || block_data[114] != 61 ||
            block_data[115] != 31 || block_data[116] != 45 || block_data[117] != 8)
            $fatal(1, "EDID range excludes advertised VGA/720p modes");
        if (block_data[126] != 0) $fatal(1, "Unexpected EDID extensions");

        // Random reads, STOP-separated offsets, and current-address reads.
        set_offset(54); i2c_stop();
        i2c_start(); i2c_write(8'ha1, 1); i2c_read(value, 0); i2c_stop();
        if (value !== block_data[54]) $fatal(1, "STOP-separated offset lost");
        i2c_start(); i2c_write(8'ha1, 1); i2c_read(value, 0); i2c_stop();
        if (value !== block_data[55]) $fatal(1, "Current address did not advance after NACK");
        begin_read(127); i2c_read(value, 1);
        if (value !== block_data[127]) $fatal(1, "Random read failed");
        i2c_read(value, 0); i2c_stop();
        if (value !== 8'hff) $fatal(1, "Read outside EDID did not return ff");

        // No HDMI/HDCP/SCDC or extra EDID segments are advertised or served.
        i2c_start(); i2c_write(8'h60, 0); i2c_stop();
        i2c_start(); i2c_write(8'he8, 0); i2c_stop();
        set_offset(0); i2c_write(8'hf0, 0); i2c_stop();
        begin_read(0); i2c_read(value, 0); i2c_stop();
        if (value !== 0) $fatal(1, "Write changed EDID ROM");

        // A repeated START also recovers an aborted transfer.
        i2c_start(); i2c_write(8'ha0, 1);
        begin_read(8); i2c_read(value, 0); i2c_stop();
        if (value !== block_data[8]) $fatal(1, "Repeated START recovery failed");
        // Reset while the slave is transmitting a zero bit must release SDA.
        begin_read(0);
        if (sda !== 0) $fatal(1, "Expected EDID zero bit before reset");
        rst = 1;
        repeat (4) @(negedge clk);
        if (sda !== 1) $fatal(1, "Reset left SDA stuck low");
        i2c_stop(); rst = 0;
        half_period = 1250; // also exercise sampling at 400 kHz
        begin_read(35); i2c_read(value, 0); i2c_stop();
        if (value !== 8'h20) $fatal(1, "DDC recovery/fast read failed");
        $display("FPGA_VIDEO_PASS core");
        $finish;
    end
    initial begin
        #30000000;
        $fatal(1, "EDID test timeout");
    end
endmodule

`default_nettype wire
