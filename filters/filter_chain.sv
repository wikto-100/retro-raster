`default_nettype none

// Filter chain: the eight filters DP0-DP7 in a row. Every pixel passes
// through all eight, one clock tick each. Only the filter whose switch is
// selected changes the pixel; the others pass it through.
//
// Which filter is selected: the first switch turned on stays selected until
// it is turned off. Then the lowest-numbered switch still on is selected.
// The choice only changes at the start of a frame (VSYNC), so a frame is
// never half filtered.
module filter_chain (
    input wire pixel_clk, reset,
    input wire [7:0] enable, // bit n = 1 when switch DPn is ON
    input wire [23:0] rgb_in,
    input wire de_in, hsync_in, vsync_in,
    output wire [23:0] rgb_out,
    output wire de_out, hsync_out, vsync_out
);
    (* ASYNC_REG = "TRUE" *) reg [7:0] enable_sync0 = 0, enable_sync1 = 0;
    reg [7:0] frame_enable = 0; // selected filter: one bit set, or none
    reg vsync_previous = 0;
    // The switches pass through a two-stage synchronizer (enable_sync0/1).
    // At each VSYNC rising edge: if the selected switch is still on, keep it;
    // otherwise select the lowest switch that is on (or none).
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            enable_sync0 <= 0; enable_sync1 <= 0; frame_enable <= 0; vsync_previous <= 0;
        end else begin
            enable_sync0 <= enable;
            enable_sync1 <= enable_sync0;
            vsync_previous <= vsync_in;
            if (vsync_in && !vsync_previous && !(frame_enable & enable_sync1))
                // x & -x keeps only the lowest 1 bit of x.
                frame_enable <= enable_sync1 & (~enable_sync1 + 1'b1);
        end
    end

    // Pixel position for the filters. x counts pixels along the line (0-1279)
    // and resets in blanking. y counts lines (0-719) and resets at VSYNC.
    // Stage n sees the pixel n ticks later, so its x/y is delayed n ticks.
    reg [10:0] x_count = 0, y_count = 0;
    reg de_previous = 0;
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            x_count <= 0; y_count <= 0; de_previous <= 0;
        end else begin
            de_previous <= de_in;
            x_count <= de_in ? x_count + 1'b1 : 11'd0;
            if (vsync_in && !vsync_previous) y_count <= 0;
            else if (de_previous && !de_in) y_count <= y_count + 1'b1;
        end
    end
    reg [10:0] x [0:7], y [0:7];
    always @* begin x[0] = x_count; y[0] = y_count; end
    genvar stage;
    generate for (stage = 1; stage < 8; stage = stage + 1) begin : position_delay
        always @(posedge pixel_clk) begin
            x[stage] <= x[stage - 1];
            y[stage] <= y[stage - 1];
        end
    end endgenerate

    // Pixel buses between stages: bus 0 is the input, bus 8 the output.
    wire [23:0] rgb [0:8];
    wire de [0:8], hs [0:8], vs [0:8];
    assign {rgb[0], de[0], hs[0], vs[0]} = {rgb_in, de_in, hsync_in, vsync_in};
    assign {rgb_out, de_out, hsync_out, vsync_out} = {rgb[8], de[8], hs[8], vs[8]};
    // FILTER_STAGE connects filter n from bus n to bus n + 1. It is a text
    // macro that saves writing the same port list eight times.
`define FILTER_STAGE(name, instance, n) \
    name instance ( \
        .pixel_clk(pixel_clk), .reset(reset), .enable(frame_enable[n]), .x(x[n]), .y(y[n]), \
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
