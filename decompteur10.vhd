--------------------------------------------------------------------------------
-- Module Name: decompteur10 - Behavioral
-- Description: Modulo-10 BCD down-counter (tens digit for game timer).
--              Decrements when triggered by units overflow and generates a 
--              terminal count signal upon reaching zero.
-- Target Board: Intel DE10-Lite (MAX 10 FPGA)
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity decompteur10 is
    Port (
        clk          : in  STD_LOGIC;  -- Clock input (pulse from units counter)
        reset        : in  STD_LOGIC;  -- Active-high reset
        q0           : out STD_LOGIC;  -- Output bit Q0
        q1           : out STD_LOGIC;  -- Output bit Q1
        q2           : out STD_LOGIC;  -- Output bit Q2
        q3           : out STD_LOGIC;  -- Output bit Q3
        reset_signal : out STD_LOGIC   -- Terminal count / reload trigger pulse
    );
end decompteur10;

architecture Behavioral of decompteur10 is
    signal compteur : STD_LOGIC_VECTOR(3 downto 0) := "1001"; -- Initialized to 9 ("1001")
begin

process(clk, reset)
begin
    if reset = '1' then
        compteur     <= "0000"; -- Reset counter to 0
        reset_signal <= '0';    -- Clear trigger during reset
    elsif rising_edge(clk) then
        if compteur = "0000" then -- If counter reaches 0
            compteur     <= "1001"; -- Reload to 9
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

