--------------------------------------------------------------------------------
-- Module Name: decompteur9 - Behavioral
-- Description: Modulo-10 BCD down-counter (counts 9 down to 0). Used for timer
--              countdown in timed modes (e.g. Zen / Arcade). Generates a reload
--              trigger pulse when reaching 0.
-- Target Board: Intel DE10-Lite (MAX 10 FPGA)
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity decompteur9 is
    Port (
        clk          : in  STD_LOGIC;  -- Clock input (1 Hz timer pulse)
        reset        : in  STD_LOGIC;  -- Active-high reset
        q0           : out STD_LOGIC;  -- Output bit Q0
        q1           : out STD_LOGIC;  -- Output bit Q1
        q2           : out STD_LOGIC;  -- Output bit Q2
        q3           : out STD_LOGIC;  -- Output bit Q3
        reset_signal : out STD_LOGIC   -- Terminal count / reload trigger pulse
    );
end decompteur9;

architecture Behavioral of decompteur9 is
    signal compteur : STD_LOGIC_VECTOR(3 downto 0) := "1001"; -- Initialized to 9 ("1001")
begin

process(clk, reset)
begin
    if reset = '1' then
        compteur     <= "1001"; -- Reset counter to 9
        reset_signal <= '0';    -- Clear trigger during reset
    elsif rising_edge(clk) then
        if compteur = "0000" then -- If counter reaches 0
            compteur     <= "1000"; -- Reload value
            reset_signal <= '1';    -- Assert terminal pulse
        else
            compteur     <= compteur - 1; -- Decrement counter
            reset_signal <= '0';          -- Deassert terminal pulse
        end if;
    end if;
end process;

-- Output assignments
q0 <= compteur(0);
q1 <= compteur(1);
q2 <= compteur(2);
q3 <= compteur(3);

end Behavioral;

