`default_nettype none
// Read-only measurements in the decoded pixel domain; all counters wrap.
module video_probe (
    input wire clk, reset, de, hsync, vsync,
    output wire [127:0] status
);
    reg old_de = 0, old_hs = 0, old_vs = 0;
    reg [31:0] frame_ticks = 0, last_frame_ticks = 0;
    reg [21:0] active_pixels = 0, last_active_pixels = 0;
    reg [9:0] rows = 0, last_rows = 0;
    reg [10:0] width_count = 0, last_width = 0;
    reg [12:0] line_ticks = 0, last_line_ticks = 0;
    reg [7:0] hs_ticks = 0, last_hs_ticks = 0;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            old_de <= 0; old_hs <= 0; old_vs <= 0;
            frame_ticks <= 0; last_frame_ticks <= 0;
            active_pixels <= 0; last_active_pixels <= 0;
            rows <= 0; last_rows <= 0; width_count <= 0; last_width <= 0;
            line_ticks <= 0; last_line_ticks <= 0;
            hs_ticks <= 0; last_hs_ticks <= 0;
        end else begin
            old_de <= de; old_hs <= hsync; old_vs <= vsync;
            frame_ticks <= frame_ticks + 1'b1;
            line_ticks <= line_ticks + 1'b1;
            if (de) begin
                active_pixels <= active_pixels + 1'b1;
                width_count <= width_count + 1'b1;
            end
            if (old_de && !de) begin
                last_width <= width_count;
                width_count <= 0;
                rows <= rows + 1'b1;
            end
            if (hsync) hs_ticks <= hs_ticks + 1'b1;
            if (old_hs && !hsync) begin last_hs_ticks <= hs_ticks; hs_ticks <= 0; end
            if (hsync && !old_hs) begin
                last_line_ticks <= line_ticks;
                line_ticks <= 1;
            end
            if (vsync && !old_vs) begin
                last_frame_ticks <= frame_ticks;
                frame_ticks <= 1;
                last_active_pixels <= active_pixels;
                last_rows <= rows;
                active_pixels <= 0; rows <= 0;
            end
        end
    end
    assign status = {32'h720a7d00, last_frame_ticks, last_active_pixels, last_rows,
                     last_hs_ticks, last_width, last_line_ticks};
endmodule
`default_nettype wire
