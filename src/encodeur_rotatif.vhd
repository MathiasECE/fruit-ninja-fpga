--------------------------------------------------------------------------------
-- Module Name: encodeur_rotatif - Behavioral
-- Description: Rotary encoder quadrature decoder with integrated digital 
--              debouncing (filtering) and bounded angular position output.
-- Target Board: Intel DE10-Lite (MAX 10 FPGA)
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity encodeur_rotatif is
    Port (
        clk         : in  STD_LOGIC;                         -- 25 MHz system clock
        encoder_A   : in  STD_LOGIC;                         -- Rotary encoder channel A
        encoder_B   : in  STD_LOGIC;                         -- Rotary encoder channel B
        angle_out   : out STD_LOGIC_VECTOR(4 downto 0)       -- 5-bit bounded angle index (0 to 18)
    );
end encodeur_rotatif;

architecture Behavioral of encodeur_rotatif is
    signal A_clean, B_clean : std_logic := '1';
    signal A_prev           : std_logic := '1';
    signal count            : integer range 0 to 18 := 9;    -- Initialized at center (index 9 = 0 degrees)
begin
    process(clk)
        variable filter_A, filter_B : integer range 0 to 50000 := 0;
    begin
        if rising_edge(clk) then
            -- Digital debounce filter for channel A (2 ms integration at 25 MHz)
            if encoder_A = '1' then
                if filter_A < 50000 then filter_A := filter_A + 1; else A_clean <= '1'; end if;
            else
                if filter_A > 0 then filter_A := filter_A - 1; else A_clean <= '0'; end if;
            end if;
            
            -- Digital debounce filter for channel B (2 ms integration at 25 MHz)
            if encoder_B = '1' then
                if filter_B < 50000 then filter_B := filter_B + 1; else B_clean <= '1'; end if;
            else
                if filter_B > 0 then filter_B := filter_B - 1; else B_clean <= '0'; end if;
            end if;
            
            -- Quadrature decoding: detect falling edge on filtered channel A
            if A_prev = '1' and A_clean = '0' then
                if B_clean = '0' then
                    if count < 18 then count <= count + 1; end if;  -- Clockwise rotation
                else
                    if count > 0 then count <= count - 1; end if;   -- Counter-clockwise rotation
                end if;
            end if;
            
            A_prev <= A_clean;
        end if;
    end process;
    
    -- Output angle count as a 5-bit unsigned vector
    angle_out <= std_logic_vector(to_unsigned(count, 5));
end Behavioral;
