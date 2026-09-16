--------------------------------------------------------------------------------
-- Module Name: reset_gate - Behavioral
-- Description: System reset logic combiner. Combines active-high Game Over trigger
--              (IN1) and active-low physical push-button KEY0 (IN2) into an
--              active-low global reset signal (reset_out).
-- Target Board: Intel DE10-Lite (MAX 10 FPGA)
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity reset_gate is
    port (
        IN1       : in  std_logic;  -- Game_Over trigger (active-high: '1')
        IN2       : in  std_logic;  -- KEY0 push-button (active-low: '0')
        reset_out : out std_logic   -- Combined system reset (active-low: '0')
    );
end reset_gate;

architecture Behavioral of reset_gate is
begin
    -- Assert reset ('0') if KEY0 is pressed ('0') OR Game_Over is asserted ('1')
    reset_out <= '0' when (IN2 = '0' or IN1 = '1') else '1';
end Behavioral;


