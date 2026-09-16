--------------------------------------------------------------------------------
-- Module Name: measurement_cal - Behavioral
-- Description: Ultrasonic distance calculation module. Converts HC-SR04 echo pulse
--              duration into distance (in mm) using fixed-point reciprocal multiplication.
-- Target Board: Intel DE10-Lite (MAX 10 FPGA)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity measurement_cal is
    generic (
        ns_cycel       : unsigned(4 downto 0)  := to_unsigned(20, 5);          -- 20 ns clock period (50 MHz)
        division_cons  : unsigned(29 downto 0) := to_unsigned(758283881, 30)  -- 2^42 / (1000 * 5.8) fixed-point factor for mm
    );		
    port (
        -- Inputs
        i_Clock           : in  std_logic;
        i_Reset_n         : in  std_logic;
        i_Echo_pulse_time : in  std_logic_vector(23 downto 0); -- Clock cycles elapsed during echo high pulse
        i_DV_n            : in  std_logic;                     -- Data valid (active-low: '0' when measurement ready)

        -- Outputs
        o_Distance        : out std_logic_vector(13 downto 0); -- Measured distance in millimeters
        o_DV_n            : out std_logic                      -- Output data valid flag
    );
end measurement_cal;

architecture Behavioral of measurement_cal is

    -- State machine definition
    type state_type is (idle, counting);
    signal state  : state_type;
    signal result : unsigned(13 downto 0);

begin

    process(i_Clock, i_Reset_n)
        variable time_ns          : unsigned(28 downto 0);
        variable val_in_const_val : unsigned(58 downto 0);
    begin
        if i_Reset_n = '0' then
            val_in_const_val := (others => '0');
            time_ns          := (others => '0');
            result           <= (others => '0');
            state            <= idle;
            
        elsif rising_edge(i_Clock) then
            case state is
                when idle =>
                    val_in_const_val := (others => '0');
                    time_ns          := (others => '0');
                    -- Maintain previous stable distance reading between ultrasound pings
                    
                    if i_DV_n = '0' then
                        state <= counting;
                    else
                        state <= idle;
                    end if;
                        
                when counting =>
                    -- Convert clock cycle count to nanoseconds
                    time_ns          := unsigned(i_Echo_pulse_time) * ns_cycel;
                    -- Multiply by fixed-point factor
                    val_in_const_val := time_ns * division_cons;
                    
                    -- Extract integer distance in millimeters
                    result           <= val_in_const_val(55 downto 42);
                    state            <= idle;
            end case;
        end if;
    end process;
    
    o_DV_n     <= '0' when state = counting else '1';
    o_Distance <= std_logic_vector(result);

end Behavioral;