`default_nettype none

module tmds_serializer (
    input  wire       pixel_clk,
    input  wire       serial_clk,
    input  wire       rst,
    input  wire [9:0] symbol,
    output wire       out_p,
    output wire       out_n
);
    wire shift1;
    wire shift2;
    wire serial_data;

    // OSERDESE2 transmits D1 first. TMDS symbols are sent least-significant bit first.
    OSERDESE2 #(
        .DATA_RATE_OQ("DDR"), .DATA_RATE_TQ("SDR"), .DATA_WIDTH(10),
        .SERDES_MODE("MASTER"), .TRISTATE_WIDTH(1)
    ) master (
        .CLK(serial_clk), .CLKDIV(pixel_clk), .RST(rst), .OCE(1'b1),
        .D1(symbol[0]), .D2(symbol[1]), .D3(symbol[2]), .D4(symbol[3]),
        .D5(symbol[4]), .D6(symbol[5]), .D7(symbol[6]), .D8(symbol[7]),
        .SHIFTIN1(shift1), .SHIFTIN2(shift2), .SHIFTOUT1(), .SHIFTOUT2(),
        .OQ(serial_data), .OFB(), .TQ(), .TFB(), .TBYTEOUT(),
        .T1(1'b0), .T2(1'b0), .T3(1'b0), .T4(1'b0), .TCE(1'b0), .TBYTEIN(1'b0)
    );
    OSERDESE2 #(
        .DATA_RATE_OQ("DDR"), .DATA_RATE_TQ("SDR"), .DATA_WIDTH(10),
        .SERDES_MODE("SLAVE"), .TRISTATE_WIDTH(1)
    ) slave (
        .CLK(serial_clk), .CLKDIV(pixel_clk), .RST(rst), .OCE(1'b1),
        .D1(1'b0), .D2(1'b0), .D3(symbol[8]), .D4(symbol[9]),
        .D5(1'b0), .D6(1'b0), .D7(1'b0), .D8(1'b0),
        .SHIFTIN1(1'b0), .SHIFTIN2(1'b0), .SHIFTOUT1(shift1), .SHIFTOUT2(shift2),
        .OQ(), .OFB(), .TQ(), .TFB(), .TBYTEOUT(),
        .T1(1'b0), .T2(1'b0), .T3(1'b0), .T4(1'b0), .TCE(1'b0), .TBYTEIN(1'b0)
    );
    OBUFDS #(.IOSTANDARD("TMDS_33")) output_buffer (
        .I(serial_data), .O(out_p), .OB(out_n)
    );
endmodule

`default_nettype wire
