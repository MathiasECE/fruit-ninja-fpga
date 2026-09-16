library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SBPA is
    port (
        clk      : in std_logic;          -- Clock signal
        reset    : in std_logic;          -- Reset signal
        enable   : in std_logic;          -- Enable signal
        rnd_byte : out std_logic_vector(7 downto 0)  -- Output 8-bit random signals
    );
end entity SBPA;

architecture Behavioral of SBPA is
    signal lfsr_reg : std_logic_vector(7 downto 0) := "10101010"; -- Initial value (can be changed)
begin
    process(clk, reset)
    begin
        if reset = '1' then
            lfsr_reg <= "10101010";  -- Reset to initial value
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Feedback taps for 8-bit LFSR: x^8 + x^6 + x^5 + x^4 + 1 (0xB4)
                lfsr_reg <= lfsr_reg(6 downto 0) & (lfsr_reg(7) xor lfsr_reg(5) xor lfsr_reg(4) xor lfsr_reg(3));
            end if;
        end if;
    end process;

    -- Assign each bit of rnd_byte independently
    rnd_byte(0) <= lfsr_reg(0) xor lfsr_reg(1);
    rnd_byte(1) <= lfsr_reg(1) xor lfsr_reg(2);
    rnd_byte(2) <= lfsr_reg(2) xor lfsr_reg(3);
    rnd_byte(3) <= lfsr_reg(3) xor lfsr_reg(4);
    rnd_byte(4) <= lfsr_reg(4) xor lfsr_reg(5);
    rnd_byte(5) <= lfsr_reg(5) xor lfsr_reg(6);
    rnd_byte(6) <= lfsr_reg(6) xor lfsr_reg(7);
    rnd_byte(7) <= lfsr_reg(7) xor lfsr_reg(0);
end architecture Behavioral;
