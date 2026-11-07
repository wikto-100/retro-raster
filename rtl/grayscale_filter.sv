`default_nettype none

// Converts active video to grayscale (BT.601 luma, weights sum to 256) while
// `enable` is high. `enable` is asynchronous (a DIP switch): it is
// synchronized and only sampled at each VSYNC rising edge, so the filter
// switches on whole frames. One register stage for data and timing alike.
module grayscale_filter (
    input wire pixel_clk,
    input wire reset,
    input wire enable,
    input wire [23:0] rgb_in,
    input wire de_in, hsync_in, vsync_in,
    output reg [23:0] rgb_out = 0,
    output reg de_out = 0, hsync_out = 0, vsync_out = 0
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] enable_sync = 0;
    reg gray = 0;
    reg vsync_previous = 0;
    wire [15:0] luma = 8'd77 * rgb_in[23:16] + 8'd150 * rgb_in[15:8] + 8'd29 * rgb_in[7:0];
    wire [7:0] y = luma[15:8];
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            enable_sync <= 0;
            gray <= 0;
            vsync_previous <= 0;
            rgb_out <= 0;
            de_out <= 0;
            hsync_out <= 0;
            vsync_out <= 0;
        end else begin
            enable_sync <= {enable_sync[0], enable};
            vsync_previous <= vsync_in;
            if (vsync_in && !vsync_previous) gray <= enable_sync[1];
            rgb_out <= !de_in ? 24'b0 : gray ? {y, y, y} : rgb_in;
            de_out <= de_in;
            hsync_out <= hsync_in;
            vsync_out <= vsync_in;
        end
    end
endmodule

`default_nettype wire
