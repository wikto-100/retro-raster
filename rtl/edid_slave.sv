`default_nettype none

// Read-only E-DDC base block at 7-bit I2C address 0x50. No extensions.
// Supports offset writes, repeated START, sequential reads, ACK and NACK.
module edid_slave (
    input  wire clk, // 100 MHz; DDC up to 100 kHz
    input  wire rst,
    input  wire scl,
    input  wire sda,
    output reg  sda_low = 0 // open drain: pull low or release, never drive high
);
    // EDID 1.3, digital RGB, preferred 1280x720 60 Hz, VGA fallback, no audio/HDMI extensions.
    // Only VGA 60 is set in established timings; all standard timings are unused.
    // DTDs: 74.25 MHz 1650x750 +H/+V, then 25.18 MHz 800x525 -H/-V.
    // Byte 127 is the checksum. No CTA block: DVI-compatible RGB video only.
    localparam [1023:0] EDID = {
        128'h00ffffffffffff004a92010000000000,
        128'h00240103800000780eee91a3544c9926,
        128'h0f505420000001010101010101010101,
        128'h010101010101011d007251d01e206e28,
        128'h550000000000001ed60980a020e02d10,
        128'h1060a200000000000018000000fc0052,
        128'h6574726f5261737465720a20000000fd,
        128'h003b3d1f2d08000a2020202020200003
    };
    function automatic [7:0] edid_byte(input [7:0] address);
        edid_byte = address[7] ? 8'hff : EDID[1023 - 8*address[6:0] -: 8];
    endfunction

    (* ASYNC_REG = "TRUE" *) reg [1:0] scl_sync = 2'b11;
    (* ASYNC_REG = "TRUE" *) reg [1:0] sda_sync = 2'b11;
    reg scl_previous = 1;
    reg sda_previous = 1;
    always @(posedge clk) begin
        if (rst) begin
            scl_sync <= 2'b11;
            sda_sync <= 2'b11;
            scl_previous <= 1;
            sda_previous <= 1;
        end else begin
            scl_sync <= {scl_sync[0], scl};
            sda_sync <= {sda_sync[0], sda};
            scl_previous <= scl_sync[1];
            sda_previous <= sda_sync[1];
        end
    end
    wire scl_rise = !scl_previous && scl_sync[1];
    wire scl_fall = scl_previous && !scl_sync[1];
    wire start_bit = scl_previous && scl_sync[1] && sda_previous && !sda_sync[1];
    wire stop_bit = scl_previous && scl_sync[1] && !sda_previous && sda_sync[1];

    localparam [3:0] IDLE = 0, ADDRESS = 1, ADDRESS_ACK = 2,
        ADDRESS_ACK_END = 3, OFFSET = 4, OFFSET_ACK = 5,
        OFFSET_ACK_END = 6, IGNORE = 7, READ = 8, READ_ACK = 9, READ_NEXT = 10;
    reg [3:0] state = IDLE;
    reg [2:0] bit_index = 7;
    reg [7:0] received = 0;
    reg [7:0] offset = 0;
    reg read_mode = 0;
    reg master_ack = 0;
    wire [7:0] current_byte = edid_byte(offset);

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            bit_index <= 7;
            received <= 0;
            offset <= 0;
            read_mode <= 0;
            master_ack <= 0;
            sda_low <= 0;
        end else if (start_bit) begin
            state <= ADDRESS;
            bit_index <= 7;
            sda_low <= 0;
        end else if (stop_bit) begin
            state <= IDLE;
            sda_low <= 0;
        end else case (state)
            ADDRESS: if (scl_rise) begin
                received <= {received[6:0], sda_sync[1]};
                if (bit_index == 0) begin
                    read_mode <= sda_sync[1];
                    state <= (received[6:0] == 7'h50) ? ADDRESS_ACK : IDLE;
                end else bit_index <= bit_index - 1'b1;
            end
            ADDRESS_ACK: if (scl_fall) begin
                sda_low <= 1;
                state <= ADDRESS_ACK_END;
            end
            ADDRESS_ACK_END: if (scl_fall) begin
                bit_index <= 7;
                sda_low <= read_mode && !current_byte[7];
                state <= read_mode ? READ : OFFSET;
            end
            OFFSET: if (scl_rise) begin
                received <= {received[6:0], sda_sync[1]};
                if (bit_index == 0) begin
                    offset <= {received[6:0], sda_sync[1]};
                    state <= OFFSET_ACK;
                end else bit_index <= bit_index - 1'b1;
            end
            OFFSET_ACK: if (scl_fall) begin
                sda_low <= 1;
                state <= OFFSET_ACK_END;
            end
            OFFSET_ACK_END: if (scl_fall) begin
                sda_low <= 0;
                state <= IGNORE; // further data writes are NACKed; ROM is immutable
            end
            READ: if (scl_fall) begin
                if (bit_index == 0) begin
                    sda_low <= 0;
                    state <= READ_ACK;
                end else begin
                    bit_index <= bit_index - 1'b1;
                    sda_low <= !current_byte[bit_index - 1'b1];
                end
            end
            READ_ACK: if (scl_rise) begin
                master_ack <= !sda_sync[1];
                offset <= offset + 8'd1;
                state <= READ_NEXT;
            end
            READ_NEXT: if (scl_fall) begin
                bit_index <= 7;
                sda_low <= master_ack && !current_byte[7];
                state <= master_ack ? READ : IDLE;
            end
            default: sda_low <= 0;
        endcase
    end
endmodule

`default_nettype wire
