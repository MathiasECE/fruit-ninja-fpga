--------------------------------------------------------------------------------
-- Module Name: decompteur3 - Behavioral
-- Description: 3-life down-counter for Classic Mode. Decrements lives from 3 to 0
--              upon missed fruit or bomb strike. Triggers a Game Over pulse when
--              lives reach 0 and latches until system reset.
-- Target Board: Intel DE10-Lite (MAX 10 FPGA)
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity decompteur3 is
    Port (
        clk          : in  STD_LOGIC;  -- Life decrement pulse (triggered on miss/bomb)
        reset        : in  STD_LOGIC;  -- Active-high reset signal
        q0           : out STD_LOGIC;  -- Life count bit 0
        q1           : out STD_LOGIC;  -- Life count bit 1
        reset_signal : out STD_LOGIC   -- Game Over trigger output (active-high: '1')
    );
end decompteur3;

architecture Behavioral of decompteur3 is
    signal compteur : STD_LOGIC_VECTOR(1 downto 0) := "11";  -- 2-bit counter initialized to 3 ("11")
begin

process(clk, reset)
begin
    if reset = '1' then
        compteur     <= "11"; -- Reset to full health (3 lives)
        reset_signal <= '0';  -- Ensure no spurious Game Over during reset
    elsif rising_edge(clk) then
        if compteur = "01" then
            compteur     <= "00"; -- Last life lost (0 lives remaining)
            reset_signal <= '1';  -- Assert GAME OVER trigger
        elsif compteur = "00" then
            compteur     <= "00"; -- Lock at 0 lives
            reset_signal <= '1';  -- Maintain GAME OVER assertion
        else
            compteur     <= compteur - 1;  -- Decrement life counter
            reset_signal <= '0';
        end if;
    end if;
end process;

-- Assign counter bits to output ports
q0 <= compteur(0);
q1 <= compteur(1);

end Behavioral;

