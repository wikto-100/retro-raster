`timescale 1ns/1ps
`default_nettype none
module tmds_monitor #(
    parameter integer ACTIVE_LINES = 4,
    parameter bit CLOCK_INVERTED = 1
) (
    input wire rst, enabled, tx_clk_p,
    input wire [2:0] tx_p, tx_n,
    output integer full_frames = 0
);
    localparam real BIT_NS = 1000.0 / 742.5;
    function automatic [23:0] test_pixel(input integer x, y, frame_number);
        reg [7:0] r,g,b;
        begin
            r = x ^ frame_number;
            g = y;
            b = (x >> 3) ^ (y >> 2) ^ 8'ha5;
            test_pixel = {r,g,b};
        end
    endfunction
    function automatic integer token(input [9:0] word_in);
        case (word_in)
            10'b1101010100: token = 0;
            10'b0010101011: token = 1;
            10'b0101010100: token = 2;
            10'b1010101011: token = 3;
            default: token = -1;
        endcase
    endfunction
    function automatic [7:0] decode(input [9:0] word_in);
        reg [7:0] q;
        integer i;
        begin
            q = word_in[9] ? ~word_in[7:0] : word_in[7:0];
            decode[0] = q[0];
            for (i = 1; i < 8; i = i + 1)
                decode[i] = q[i] ^ q[i-1] ^ !word_in[8];
        end
    endfunction
    integer ox = 0, oy = 0, pixels = 0, frame_code = -1, last_frame_code = -1;
    integer sample_bit, t0, t1, t2, hs_width = 0, hs_period = 0, vs_width = 0;
    reg [9:0] observed [0:2];
    reg [23:0] observed_rgb;
    reg armed = 0, previous_de = 0, previous_hs = 0, previous_vs = 0, hs_seen = 0;
    reg have_vsync = 0, vs_width_valid = 0, hs_baseline = 0, hs_width_valid = 0;
    reg oh, ov;
    always @(posedge rst) begin
        armed = 0; previous_de = 0; previous_hs = 0; previous_vs = 0;
        hs_seen = 0; hs_width = 0; hs_period = 0; vs_width = 0;
        have_vsync = 0; vs_width_valid = 0; hs_baseline = 0; hs_width_valid = 0;
        ox = 0; oy = 0; pixels = 0; frame_code = -1; last_frame_code = -1;
    end
    initial forever begin
        // Mimas output uses the inverted forwarded clock (kClkSwap=true).
        // Choose the word boundary explicitly; still decode all ten serial bits.
        if (CLOCK_INVERTED) @(posedge tx_clk_p);
        else @(negedge tx_clk_p);
        #(BIT_NS/2);
        for (sample_bit = 0; sample_bit < 10; sample_bit = sample_bit + 1) begin
            observed[0][sample_bit] = tx_p[0];
            observed[1][sample_bit] = tx_p[1];
            observed[2][sample_bit] = tx_p[2];
            if (!rst && enabled && tx_n !== ~tx_p)
                $fatal(1, "TX differential data polarity");
            if (sample_bit != 9) #(BIT_NS);
        end
        if (!rst && enabled) begin
            t0 = token(observed[0]); t1 = token(observed[1]); t2 = token(observed[2]);
            if (t0 >= 0) begin
                oh = t0 & 1; ov = (t0 >> 1) & 1;
                if (ov && !previous_vs) begin
                    // Clock recovery can expose the middle of the first sync
                    // pulse. Only the following pulse has a measured beginning.
                    vs_width_valid = have_vsync;
                    have_vsync = 1;
                    if (armed && pixels != 0) begin
                        if (pixels != 1280*ACTIVE_LINES || oy != ACTIVE_LINES)
                            $fatal(1, "Incomplete output frame: %0d pixels, %0d lines",pixels,oy);
                        if (last_frame_code >= 0 && frame_code != ((last_frame_code+1)&255))
                            $fatal(1, "Frozen/skipped frame %0d after %0d",frame_code,last_frame_code);
                        last_frame_code = frame_code;
                        full_frames = full_frames + 1;
                        $display("Checked complete output frame %0d (source ID %0d)",full_frames,frame_code);
                    end
                    armed = 1; ox = 0; oy = 0; pixels = 0; frame_code = -1;
                end
                if (armed && (t1 != 0 || t2 != 0)) $fatal(1, "Unaligned channel controls");
                if (previous_de && armed) begin
                    if (ox != 1280) $fatal(1, "Wrong active line width: %0d",ox);
                    oy = oy + 1; ox = 0;
                end
                previous_de = 0;
            end else begin
                if (armed && (t1 >= 0 || t2 >= 0)) $fatal(1, "Channel DE mismatch");
                if (armed) begin
                    observed_rgb = {decode(observed[2]),decode(observed[1]),decode(observed[0])};
                    if (frame_code < 0) frame_code = observed_rgb[23:16];
                    if (ox >= 1280 || oy >= ACTIVE_LINES || observed_rgb !== test_pixel(ox,oy,frame_code))
                        $fatal(1,"Pixel mismatch (%0d,%0d), frame %0d: %h expected %h",ox,oy,frame_code,observed_rgb,test_pixel(ox,oy,frame_code));
                    ox = ox + 1; pixels = pixels + 1;
                end
                previous_de = 1;
                // During active video the sync levels hold their last controls.
            end
            if (armed) begin
                hs_period = hs_period + 1;
                if (!oh) hs_baseline = 1;
                if (oh && !previous_hs && hs_baseline) begin
                    if (hs_seen && hs_period != 1650) $fatal(1,"HSYNC period %0d",hs_period);
                    hs_seen = 1; hs_period = 0;
                    hs_width_valid = 1;
                end
                if (!oh && previous_hs && hs_width_valid && hs_width != 40) $fatal(1,"HSYNC width %0d",hs_width);
                if (!ov && previous_vs && vs_width_valid && vs_width != 8250) $fatal(1,"VSYNC width %0d",vs_width);
                hs_width = oh ? hs_width+1 : 0;
                vs_width = ov ? vs_width+1 : 0;
            end
            previous_hs = oh; previous_vs = ov;
        end
    end
endmodule
`default_nettype wire
