`default_nettype none

// EDID responder.
//
// When the GPU sees HPD, it reads 128 bytes from address 0x50 on the DDC
// wire pair (an I2C bus: SCL is the clock, SDA the data). This module plays
// that memory chip. The GPU first writes an offset (which byte to start
// at), then reads bytes one after another. After each byte the receiver of
// the byte answers ACK (pulls SDA low for one bit) to say "got it".
module edid_slave (
    input  wire clk, // 100 MHz, much faster than DDC (up to 400 kHz)
    input  wire rst,
    input  wire scl,
    input  wire sda,
    output reg  sda_low = 0 // 1 = pull SDA low; 0 = let go (SDA floats high)
);
    // The 128 EDID bytes, first byte at the left. They say: EDID version 1.3,
    // digital RGB display named "RetroRaster", one mode: 1280x720 at 60 Hz
    // (74.25 MHz pixel clock). The last byte is a checksum.
    localparam [1023:0] EDID = {
        128'h00ffffffffffff004a92020000000000,
        128'h00240103800000780eee91a3544c9926,
        128'h0f505400000001010101010101010101,
        128'h010101010101011d007251d01e206e28,
        128'h550000000000001e0000001000000000,
        128'h00000000000000000000000000fc0052,
        128'h6574726f5261737465720a20000000fd,
        128'h003c3c2d2d08000a202020202020006a
    };
    // Byte at a given offset. Offsets past 127 read as 0xFF.
    function automatic [7:0] edid_byte(input [7:0] address);
        edid_byte = address[7] ? 8'hff : EDID[1023 - 8*address[6:0] -: 8];
    endfunction

    // SCL and SDA come from the GPU at any time, so each passes through a
    // two-flip-flop synchronizer. *_previous keeps last tick's value so we
    // can see when a line changes.
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
    // I2C rules: data bits are read when SCL rises and changed when SCL falls.
    // SDA falling while SCL is high = START (a new message begins).
    // SDA rising while SCL is high = STOP (the message ends).
    wire scl_rise = !scl_previous && scl_sync[1];
    wire scl_fall = scl_previous && !scl_sync[1];
    wire start_bit = scl_previous && scl_sync[1] && sda_previous && !sda_sync[1];
    wire stop_bit = scl_previous && scl_sync[1] && !sda_previous && sda_sync[1];

    // State machine: which part of the I2C message we are in.
    //   IDLE            waiting for START
    //   ADDRESS         receiving the 7-bit device address + read/write bit
    //   ADDRESS_ACK(_END) answering ACK if the address is ours (0x50)
    //   OFFSET          receiving the byte offset
    //   OFFSET_ACK(_END)  answering ACK for the offset
    //   IGNORE          ignoring further writes (the EDID cannot be changed)
    //   READ            sending one byte, highest bit first
    //   READ_ACK        reading the GPU's ACK (it wants another byte) or NACK
    //   READ_NEXT       starting the next byte, or stopping after a NACK
    localparam [3:0] IDLE = 0, ADDRESS = 1, ADDRESS_ACK = 2,
        ADDRESS_ACK_END = 3, OFFSET = 4, OFFSET_ACK = 5,
        OFFSET_ACK_END = 6, IGNORE = 7, READ = 8, READ_ACK = 9, READ_NEXT = 10;
    reg [3:0] state = IDLE;
    reg [2:0] bit_index = 7;     // which bit of the byte, 7 down to 0
    reg [7:0] received = 0;      // bits shifted in from the GPU
    reg [7:0] offset = 0;        // next EDID byte to send
    reg read_mode = 0;           // GPU asked to read (1) or write (0)
    reg master_ack = 0;          // GPU answered ACK after our byte
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
        // START and STOP can come at any time and override the state.
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
                state <= IGNORE;
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
