library ieee;
use ieee.std_logic_1164.all;

-- HDMI receiver: wraps Digilent's dvi2rgb core (vendor/digilent).
-- HDMI sends each color as a fast serial bit stream (TMDS: 10 bits per pixel
-- per lane). The core samples those bits, finds where each pixel starts and
-- decodes them back to 8-bit color plus DE/HSYNC/VSYNC. It also rebuilds
-- the pixel clock from the HDMI clock lane. Set up for 720p only.
entity hdmi_rx is
    port (
        ref_clk, reset : in std_logic;
        tmds_clk_p, tmds_clk_n : in std_logic;
        tmds_p, tmds_n : in std_logic_vector(2 downto 0);
        pixel_clk, serial_clk, locked : out std_logic;
        rgb : out std_logic_vector(23 downto 0);
        de, hsync, vsync : out std_logic;
        debug : out std_logic_vector(15 downto 0)
    );
end entity;

architecture rtl of hdmi_rx is
    signal rbg : std_logic_vector(23 downto 0);
begin
    -- The core outputs red, blue, green; reorder to red, green, blue.
    rgb <= rbg(23 downto 16) & rbg(7 downto 0) & rbg(15 downto 8);
    core : entity work.dvi2rgb
        generic map (
            kEmulateDDC => false, kRstActiveHigh => true,
            kAddBUFG => true, kClkRange => 2, kDebug => false,
            kIDLY_TapValuePs => 78, kIDLY_TapWidth => 5
        )
        port map (
            TMDS_Clk_p => tmds_clk_p, TMDS_Clk_n => tmds_clk_n,
            TMDS_Data_p => tmds_p, TMDS_Data_n => tmds_n,
            RefClk => ref_clk, aRst => reset, aRst_n => '1',
            vid_pData => rbg, vid_pVDE => de,
            vid_pHSync => hsync, vid_pVSync => vsync,
            PixelClk => pixel_clk, SerialClk => serial_clk,
            pLocked => locked, aPixelClkLckd => open, rrDebug => debug,
            SDA_I => '1', SDA_O => open, SDA_T => open,
            SCL_I => '1', SCL_O => open, SCL_T => open,
            pRst => '0', pRst_n => '1'
        );
end architecture;
