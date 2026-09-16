--------------------------------------------------------------------------------
-- Module Name: vga_sync - Behavioral
-- Description: VGA Timing Controller for standard 640x480 @ 60 Hz resolution.
--              Generates HSYNC, VSYNC, active display area gate (inDisplayArea),
--              beam pixel coordinates (x, y), and end-of-frame pulse (frame).
-- Target Board: Intel DE10-Lite (MAX 10 FPGA)
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity vga_sync is
    generic (
        hpixels : integer := 800;     -- Total horizontal pixels per scanline
        vlines  : integer := 525;     -- Total vertical lines per video frame
        hpulse  : integer := 96;      -- HSYNC pulse width in pixel clocks
        vpulse  : integer := 2;       -- VSYNC pulse width in scanlines
        hbp     : integer := 48;      -- Horizontal back porch
        hfp     : integer := 16;      -- Horizontal front porch
        vbp     : integer := 33;      -- Vertical back porch
        vfp     : integer := 10       -- Vertical front porch        
    );
    port (
        clk25           : in  std_logic;                    -- 25 MHz pixel clock
        rst             : in  std_logic;                    -- Active-low reset signal
        x, y            : out std_logic_vector(9 downto 0); -- Current raster beam coordinates (0-639, 0-479)
        inDisplayArea   : out std_logic;                    -- High ('1') within visible active 640x480 area
        hsync, vsync    : out std_logic;                    -- Negative-polarity sync pulses
        frame           : out std_logic                     -- 1-cycle vertical sync pulse at start of blanking
    );
end vga_sync;

architecture Behavioral of vga_sync is

    signal counterX, counterY : unsigned(9 downto 0) := (others => '0');

begin

    process(clk25, rst)
    begin
        if rst = '0' then  -- Reset raster counters on active-low reset
            counterX <= (others => '0');
            counterY <= (others => '0');
        elsif rising_edge(clk25) then
            if counterX < hpixels - 1 then
                counterX <= counterX + 1;
            else
                counterX <= (others => '0');
                if counterY < vlines - 1 then
                    counterY <= counterY + 1;
                else
                    counterY <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    -- Horizontal synchronization pulse (active-low negative logic)
    hsync <= '0' when (counterX >= (hpixels - hbp - hpulse) and 
                       counterX < (hpixels - hbp)) else '1';
    
    -- Vertical synchronization pulse (active-low negative logic)
    vsync <= '0' when (counterY >= (vlines - vbp - vpulse) and 
                       counterY < (vlines - vbp)) else '1';

    -- inDisplayArea = '1' while beam is inside visible active display rectangle (640 x 480)
    inDisplayArea <= '1' when (counterX < (hpixels - hbp - hfp - hpulse) and 
                               counterY < (vlines - vbp - vfp - vpulse)) 
                    else '0';

    -- Output current pixel beam coordinates
    x <= std_logic_vector(counterX);
    y <= std_logic_vector(counterY);

    -- Frame pulse: asserted at the start of scanline 480 (active frame end / V-blank start)
    frame <= '1' when (counterX = 0 and 
                       counterY = (vlines - vpulse - vfp - vbp)) else '0';

end Behavioral;

