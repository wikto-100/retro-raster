// Included inside testbenches that provide scl, tri1 sda and master_sda_low.
integer half_period = 5000; // 100 kHz DDC, in ns
task automatic i2c_start;
    begin
        scl = 0;
        master_sda_low = 0;
        #(half_period);
        scl = 1;
        #(half_period);
        master_sda_low = 1;
        #(half_period);
        scl = 0;
        #(half_period);
    end
endtask
task automatic i2c_stop;
    begin
        scl = 0;
        master_sda_low = 1;
        #(half_period);
        scl = 1;
        #(half_period);
        master_sda_low = 0;
        #(half_period);
        if (sda !== 1) $fatal(1, "DDC not released after STOP");
    end
endtask
task automatic i2c_write(input [7:0] value, input expect_ack);
    integer bit_number;
    begin
        for (bit_number = 7; bit_number >= 0; bit_number = bit_number - 1) begin
            master_sda_low = !value[bit_number];
            #(half_period);
            scl = 1;
            #(half_period);
            if (sda !== value[bit_number]) $fatal(1, "DDC contention during write");
            scl = 0;
        end
        master_sda_low = 0;
        #(half_period);
        scl = 1;
        #(half_period);
        if (sda !== !expect_ack) $fatal(1, "ACK mismatch for byte %h", value);
        scl = 0;
        #(half_period);
    end
endtask
task automatic i2c_read(output [7:0] value, input ack);
    integer bit_number;
    begin
        master_sda_low = 0;
        for (bit_number = 7; bit_number >= 0; bit_number = bit_number - 1) begin
            #(half_period);
            scl = 1;
            #(half_period);
            value[bit_number] = sda;
            scl = 0;
        end
        #(half_period);
        master_sda_low = ack;
        #(half_period);
        scl = 1;
        #(half_period);
        scl = 0;
        #(half_period);
        master_sda_low = 0;
    end
endtask
task automatic set_offset(input [7:0] address);
    begin
        i2c_start();
        i2c_write(8'ha0, 1);
        i2c_write(address, 1);
    end
endtask
task automatic begin_read(input [7:0] address);
    begin
        set_offset(address);
        i2c_start(); // repeated START, no intervening STOP
        i2c_write(8'ha1, 1);
    end
endtask
