`default_nettype none

module video_source (
    input  wire       clk,
    input  wire       rst,
    output wire [9:0] x,
    output wire [9:0] y,
    output wire       active,
    output wire       hsync,
    output wire       vsync,
    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue,
    output wire [9:0] tmds_blue,
    output wire [9:0] tmds_green,
    output wire [9:0] tmds_red
);
    wire frame_tick;
    video_timing timing (
        .clk(clk), .rst(rst), .x(x), .y(y), .active(active),
        .hsync(hsync), .vsync(vsync), .frame_tick(frame_tick)
    );
    moving_pattern pattern (
        .clk(clk), .rst(rst), .frame_tick(frame_tick), .active(active),
        .x(x), .y(y), .red(red), .green(green), .blue(blue)
    );
    // DVI control bits occupy only the blue lane, C1=VSYNC and C0=HSYNC.
    tmds_encoder encode_blue (
        .clk(clk), .rst(rst), .active(active), .control({vsync, hsync}),
        .data(blue), .symbol(tmds_blue)
    );
    tmds_encoder encode_green (
        .clk(clk), .rst(rst), .active(active), .control(2'b00),
        .data(green), .symbol(tmds_green)
    );
    tmds_encoder encode_red (
        .clk(clk), .rst(rst), .active(active), .control(2'b00),
        .data(red), .symbol(tmds_red)
    );
endmodule

`default_nettype wire
