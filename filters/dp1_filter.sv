`default_nettype none

// DP1: green-screen terminal, like an old green phosphor CRT monitor.
// Each pixel's brightness picks a shade between dark green-black (#020D05)
// and bright green (#33FF66). Every second row is dimmed to 60% to imitate
// the dark gaps between a CRT's scan lines.
module dp1_filter (
    input wire pixel_clk, reset, enable,
    input wire [10:0] x, y,
    input wire [23:0] rgb_in,
    input wire de_in, hsync_in, vsync_in,
    output reg [23:0] rgb_out = 0,
    output reg de_out = 0, hsync_out = 0, vsync_out = 0
);
    // Brightness 0-255, as in DP0: (77R + 150G + 29B) / 256.
    wire [15:0] luma16 = 8'd77 * rgb_in[23:16] + 8'd150 * rgb_in[15:8] + 8'd29 * rgb_in[7:0];
    wire [7:0] luma = luma16[15:8];
    // Each color channel = base + brightness * gain / 256. base is the
    // channel's value at black, base + gain its value at full brightness.
    // On odd rows (y[0] = 1) base and gain are 154/256 (60%) of the normal
    // values, which dims the whole row.
    wire scanline = y[0];
    wire [7:0] r_base = scanline ? 8'd1 : 8'd2,  r_gain = scanline ? 8'd29  : 8'd49;
    wire [7:0] g_base = scanline ? 8'd8 : 8'd13, g_gain = scanline ? 8'd146 : 8'd242;
    wire [7:0] b_base = scanline ? 8'd3 : 8'd5,  b_gain = scanline ? 8'd58  : 8'd97;
    wire [15:0] r = luma * r_gain, g = luma * g_gain, b = luma * b_gain;
    wire [23:0] phosphor = {r_base + r[15:8], g_base + g[15:8], b_base + b[15:8]};
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            rgb_out <= 0; de_out <= 0; hsync_out <= 0; vsync_out <= 0;
        end else begin
            // Blanking stays black. If selected, output the green shade.
            rgb_out <= !de_in ? 24'b0 : enable ? phosphor : rgb_in;
            de_out <= de_in; hsync_out <= hsync_in; vsync_out <= vsync_in;
        end
    end
endmodule

`default_nettype wire
