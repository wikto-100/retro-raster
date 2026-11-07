`default_nettype none

// Runs the DP0..DP7 filters in series. Each filter has the same ports, adds
// one register stage to RGB and timing alike, and filters active pixels while
// its `enable` is high. The switches are asynchronous: they are synchronized
// here and only sampled at VSYNC, so filters switch on whole frames.
//
// Filters are exclusive: at most one `enable` is high. The first switch turned
// on keeps the picture while it stays on; other switches have no effect. When
// it turns off, the lowest-numbered switch still on (if any) takes over.
module filter_chain (
    input wire pixel_clk, reset,
    input wire [7:0] enable, // bit n = DPn is ON
    input wire [23:0] rgb_in,
    input wire de_in, hsync_in, vsync_in,
    output wire [23:0] rgb_out,
    output wire de_out, hsync_out, vsync_out
);
    (* ASYNC_REG = "TRUE" *) reg [7:0] enable_sync0 = 0, enable_sync1 = 0;
    reg [7:0] frame_enable = 0; // one-hot or zero
    reg vsync_previous = 0;
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            enable_sync0 <= 0; enable_sync1 <= 0; frame_enable <= 0; vsync_previous <= 0;
        end else begin
            enable_sync0 <= enable;
            enable_sync1 <= enable_sync0;
            vsync_previous <= vsync_in;
            if (vsync_in && !vsync_previous && !(frame_enable & enable_sync1))
                frame_enable <= enable_sync1 & (~enable_sync1 + 1'b1); // lowest set bit
        end
    end

    wire [23:0] rgb [0:8];
    wire de [0:8], hs [0:8], vs [0:8];
    assign {rgb[0], de[0], hs[0], vs[0]} = {rgb_in, de_in, hsync_in, vsync_in};
    assign {rgb_out, de_out, hsync_out, vsync_out} = {rgb[8], de[8], hs[8], vs[8]};
`define FILTER_STAGE(name, instance, n) \
    name instance ( \
        .pixel_clk(pixel_clk), .reset(reset), .enable(frame_enable[n]), \
        .rgb_in(rgb[n]), .de_in(de[n]), .hsync_in(hs[n]), .vsync_in(vs[n]), \
        .rgb_out(rgb[n+1]), .de_out(de[n+1]), .hsync_out(hs[n+1]), .vsync_out(vs[n+1]) \
    );
    `FILTER_STAGE(dp0_filter, stage0, 0)
    `FILTER_STAGE(dp1_filter, stage1, 1)
    `FILTER_STAGE(dp2_filter, stage2, 2)
    `FILTER_STAGE(dp3_filter, stage3, 3)
    `FILTER_STAGE(dp4_filter, stage4, 4)
    `FILTER_STAGE(dp5_filter, stage5, 5)
    `FILTER_STAGE(dp6_filter, stage6, 6)
    `FILTER_STAGE(dp7_filter, stage7, 7)
`undef FILTER_STAGE
endmodule

`default_nettype wire
