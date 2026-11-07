library ieee;
use ieee.std_logic_1164.all;

entity hdmi_tx is
    port (
        pixel_clk, serial_clk, reset : in std_logic;
        rgb : in std_logic_vector(23 downto 0);
        de, hsync, vsync : in std_logic;
        tmds_clk_p, tmds_clk_n : out std_logic;
        tmds_p, tmds_n : out std_logic_vector(2 downto 0)
    );
end entity;

architecture rtl of hdmi_tx is
begin
    -- The recovered pixel clock drives a dedicated TX PLL. The inverted clock
    -- pattern is required by the tested Mimas/monitor setup (normal RGB data).
    core : entity work.rgb2dvi
        generic map (
            kGenerateSerialClk => true, kClkPrimitive => "PLL", kRstActiveHigh => true,
            kClkRange => 2, kD0Swap => false, kD1Swap => false,
            kD2Swap => false, kClkSwap => true
        )
        port map (
            PixelClk => pixel_clk, SerialClk => serial_clk,
            aRst => reset, aRst_n => '1',
            vid_pData => rgb(23 downto 16) & rgb(7 downto 0) & rgb(15 downto 8),
            vid_pVDE => de, vid_pHSync => hsync, vid_pVSync => vsync,
            TMDS_Clk_p => tmds_clk_p, TMDS_Clk_n => tmds_clk_n,
            TMDS_Data_p => tmds_p, TMDS_Data_n => tmds_n
        );
end architecture;
