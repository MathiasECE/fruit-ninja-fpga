--------------------------------------------------------------------------------
-- Module Name: vga_mux - Behavioral
-- Description: Video Multiplexer. Switches 12-bit RGB color signals between
--              the menu user interface and the active game scene.
-- Target Board: Intel DE10-Lite (MAX 10 FPGA)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity vga_mux is
    port(
        -- Controller 1 RGB inputs (Menu Interface)
        i_R1 : in std_logic_vector(3 downto 0);
        i_G1 : in std_logic_vector(3 downto 0);
        i_B1 : in std_logic_vector(3 downto 0);

        -- Controller 2 RGB inputs (Game Scene)
        i_R2 : in std_logic_vector(3 downto 0);
        i_G2 : in std_logic_vector(3 downto 0);
        i_B2 : in std_logic_vector(3 downto 0);

        -- Video multiplexer selection signal ('0' = Menu, '1' = Game)
        selection : in std_logic;

        -- Output RGB channels directly driving VGA resistor DAC
        o_R : out std_logic_vector(3 downto 0);
        o_G : out std_logic_vector(3 downto 0);
        o_B : out std_logic_vector(3 downto 0)
    );
end vga_mux;

architecture Behavioral of vga_mux is
begin
    process(selection, i_R1, i_G1, i_B1, i_R2, i_G2, i_B2)
    begin
        if selection = '0' then
            o_R <= i_R1;
            o_G <= i_G1;
            o_B <= i_B1;
        else
            o_R <= i_R2;
            o_G <= i_G2;
            o_B <= i_B2;
        end if;
    end process;
end Behavioral;

