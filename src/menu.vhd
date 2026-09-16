--------------------------------------------------------------------------------
-- Module Name: menu - Behavioral
-- Description: Graphical Menu & User Interface Controller.
--              Handles title screen, main menu navigation (Play, Tutorial, Speed, Quit),
--              game mode selection (Classic, Zen, Arcade), and speed configuration.
--              Supports dual inputs: quadrature rotary encoder with push-button click
--              and onboard slide switches. Generates VGA raster addresses for ROM sprites.
-- Target Board: Intel DE10-Lite (MAX 10 FPGA)
--------------------------------------------------------------------------------
library IEEE; 
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity menu is
    generic (
        sprite_width  : integer := 128;    -- Menu button sprite width in pixels
        sprite_height : integer := 64;     -- Menu button sprite height in pixels
        screen_width  : integer := 640;    -- VGA display width in pixels
        screen_height : integer := 480;    -- VGA display height in pixels
        sprite_width2 : integer := 640;    -- Fullscreen splash width
        sprite_height2: integer := 480;    -- Fullscreen splash height
        sprite_width3 : integer := 320;    -- Medium submenu sprite width
        sprite_height3: integer := 240;    -- Medium submenu sprite height
        sprite_width4 : integer := 256;
        sprite_height4: integer := 192;
        sprite_width5 : integer := 224;    -- Mode submenu sprite width
        sprite_height5: integer := 168     -- Mode submenu sprite height
    );
    port (
        clk25               : in  std_logic;                    -- 25 MHz pixel clock
        rst                 : in  std_logic;                    -- System reset (active-low: '0')
        frame               : in  std_logic;                    -- Vertical blanking sync pulse
        inDisplayArea       : in  std_logic;                    -- Visible screen area flag
        x, y                : in  std_logic_vector(9 downto 0); -- Raster coordinates
        color_pixel_sprite2 : in  std_logic_vector(2 downto 0); -- Title screen sprite ROM color
        color_play          : in  std_logic_vector(2 downto 0);
        color_playselect    : in  std_logic_vector(2 downto 0);
        color_tuto          : in  std_logic_vector(2 downto 0);
        color_tutoselect    : in  std_logic_vector(2 downto 0);
        color_speed         : in  std_logic_vector(2 downto 0);
        color_speedselect   : in  std_logic_vector(2 downto 0);
        color_quit          : in  std_logic_vector(2 downto 0);
        color_quitselect    : in  std_logic_vector(2 downto 0);
        color_modeclassic   : in  std_logic_vector(2 downto 0);
        color_modezen       : in  std_logic_vector(2 downto 0);
        color_modearcade    : in  std_logic_vector(2 downto 0);
        color_speedslow     : in  std_logic_vector(2 downto 0);
        color_speedmedium   : in  std_logic_vector(2 downto 0);
        color_speedfast     : in  std_logic_vector(2 downto 0);
        color_tutorial      : in  std_logic_vector(2 downto 0);
        r, g, b             : out std_logic_vector(3 downto 0); -- VGA RGB outputs
        adr_sprite2         : out std_logic_vector(12 downto 0);
        adr_play            : out std_logic_vector(12 downto 0);
        adr_playselect      : out std_logic_vector(12 downto 0);
        adr_tuto            : out std_logic_vector(12 downto 0);
        adr_tutoselect      : out std_logic_vector(12 downto 0);
        adr_speed           : out std_logic_vector(12 downto 0);
        adr_speedselect     : out std_logic_vector(12 downto 0);
        adr_quit            : out std_logic_vector(12 downto 0);
        adr_quitselect      : out std_logic_vector(12 downto 0);
        adr_modeclassic     : out std_logic_vector(15 downto 0);
        adr_modearcade      : out std_logic_vector(15 downto 0);
        adr_modezen         : out std_logic_vector(15 downto 0);
        adr_speedslow       : out std_logic_vector(16 downto 0);
        adr_speedmedium     : out std_logic_vector(16 downto 0);
        adr_speedfast       : out std_logic_vector(16 downto 0);
        adr_tutorial        : out std_logic_vector(15 downto 0);
        switch1             : in  std_logic;                    -- Rotary encoder channel A / input 1
        switch2             : in  std_logic;                    -- Rotary encoder channel B / input 2
        switch3             : in  std_logic;                    -- Rotary encoder push button (active-low)
        confirmchoix1       : out std_logic;                    -- Game launch confirmation flag
        confirmchoix2       : out std_logic;                    -- Speed confirmation flag
        sortiesupp          : out std_logic;
        choix_jeu           : out std_logic_vector(1 downto 0); -- Selected game mode ("01"=Classic, "10"=Zen, "11"=Arcade)
        choix_speed         : out std_logic_vector(1 downto 0); -- Selected speed ("01"=Slow, "10"=Medium, "11"=Fast)
        reset_bouton        : out std_logic
    );
end menu;

architecture Behavioral of menu is
   
    -- Screen coordinates for title screen sprite (centered)
    signal x_sprite2 : integer := (screen_width - sprite_width) / 2;
    signal y_sprite2 : integer := (screen_height - sprite_width) / 2;

    -- Screen coordinates for "Play" button (idle and highlighted)
    signal x_play : integer := (screen_width - sprite_width) / 2;
    signal y_play : integer := 25;

    signal x_playselect : integer := (screen_width - sprite_width) / 2;
    signal y_playselect : integer := 25;

    -- Screen coordinates for "Tutorial" button
    signal x_tuto : integer := (screen_width - sprite_width) / 2;
    signal y_tuto : integer := 25 + sprite_height + 25;

    signal x_tutoselect : integer := (screen_width - sprite_width) / 2;
    signal y_tutoselect : integer := 25 + sprite_height + 25;

    -- Screen coordinates for "Speed" button
    signal x_speed : integer := (screen_width - sprite_width) / 2;
    signal y_speed : integer := 25 + sprite_height + 25 + sprite_height + 25;

    signal x_speedselect : integer := (screen_width - sprite_width) / 2;
    signal y_speedselect : integer := 25 + sprite_height + 25 + sprite_height + 25;

    -- Screen coordinates for "Quit" button
    signal x_quit : integer := (screen_width - sprite_width) / 2;
    signal y_quit : integer := 25 + sprite_height + 25 + sprite_height + 25 + sprite_height + 25;

    signal x_quitselect : integer := (screen_width - sprite_width) / 2;
    signal y_quitselect : integer := 25 + sprite_height + 25 + sprite_height + 25 + sprite_height + 25;

	 signal x_speedslow : integer := (screen_width - sprite_width3) / 2;
    signal y_speedslow : integer := (screen_height - sprite_height3) / 2;
    
    signal x_speedmedium : integer := (screen_width - sprite_width3) / 2;
    signal y_speedmedium : integer := (screen_height - sprite_height3) / 2;
    
    signal x_speedfast : integer := (screen_width - sprite_width3) / 2;
    signal y_speedfast : integer := (screen_height - sprite_height3) / 2;
    
	 signal x_modeclassic : integer := (screen_width - sprite_width5) / 2;
    signal y_modeclassic : integer := (screen_height - sprite_height5) / 2;
    
    signal x_modearcade : integer := (screen_width - sprite_width5) / 2;
    signal y_modearcade : integer := (screen_height - sprite_height5) / 2;
    
    signal x_modezen : integer := (screen_width - sprite_width5) / 2;
    signal y_modezen : integer := (screen_height - sprite_height5) / 2;
    
	 signal x_tutorial : integer := (screen_width - sprite_width5) / 2;
    signal y_tutorial : integer := (screen_height - sprite_height5) / 2;
	 
	 signal inSprite2 : std_logic;
    signal inPlay, inPlaySelect : std_logic;
    signal inTuto, inTutoSelect : std_logic;
    signal inSpeed, inSpeedSelect : std_logic;
    signal inQuit, inQuitSelect : std_logic;
	 signal inSpeedFast, inSpeedSlow, inSpeedMedium : std_logic;
	 signal inModeArcade, inModeZen, inModeClassic : std_logic;
	 signal inTutorial : std_logic;

    signal clk1Hz : std_logic := '0';
    signal counter : integer := 0;
	 constant y_offset : integer := 10;
    constant clk25MHz : integer := 25000000;
    signal inmenu : std_logic  := '0';
    signal choice : integer := 0;
    signal speedchoice : integer range 1 to 3 := 2;
    signal choicemode : integer range 1 to 3 := 1;
    signal ingamemode : std_logic := '0';
    signal intutorialmode : std_logic := '0';
    signal inspeedmode : std_logic := '0';
    signal inquitmode : std_logic := '0';
    signal detected_switch1 : std_logic := '0';
    signal detected_switch2 : std_logic := '0';
    signal instartmode : std_logic := '1';

    -- Internal menu item selection (0: Play/Classic/Slow, 1: Tuto/Zen/Medium, 2: Speed/Arcade/Fast, 3: Quit)
    signal sel_item : integer range 0 to 3 := 0;

    -- Rotary encoder quadrature signals (switch1 = encoder_A, switch2 = encoder_B)
    signal A_clean, B_clean : std_logic := '1';
    signal A_prev           : std_logic := '1';
    signal rot_cw           : std_logic := '0';
    signal rot_ccw          : std_logic := '0';
    signal rot_lockout      : integer range 0 to 2500000 := 0;

    -- Rotary encoder push-button signals (switch3 = encoder_SW, active-low: '0')
    signal btn_clean        : std_logic := '1';
    signal btn_prev         : std_logic := '1';
    signal btn_click        : std_logic := '0';
    signal btn_lockout      : integer range 0 to 5000000 := 0;

begin

-- Main Menu Finite State Machine & Navigation Logic
process(clk25, rst)
begin
    if rst = '0' then
        confirmchoix1  <= '0';
        confirmchoix2  <= '1'; -- Medium speed validated by default
        inmenu         <= '1'; -- Return directly to main menu
        choice         <= 0;
        speedchoice    <= 2;
        choicemode     <= 1;
        ingamemode     <= '0';
        intutorialmode <= '0';
        inspeedmode    <= '0';
        inquitmode     <= '0';
        instartmode    <= '0';
        choix_jeu      <= "00"; -- Idle game mode (game engine paused in menu)
        choix_speed    <= "10"; -- Medium speed default
        reset_bouton   <= '0';
        sortiesupp     <= '0';
        sel_item       <= 0;   -- 'Play' option selected by default
    elsif rising_edge(clk25) then
        reset_bouton <= '0';
        sortiesupp   <= '0';

        -- Bidirectional smooth menu navigation via rotary encoder
        if rot_cw = '1' then
            -- Clockwise rotation -> Next menu item
            if inmenu = '1' then
                sel_item <= (sel_item + 1) mod 4;
            elsif ingamemode = '1' then
                sel_item <= (sel_item + 1) mod 3;
            elsif inspeedmode = '1' then
                sel_item <= (sel_item + 1) mod 3;
            end if;
        elsif rot_ccw = '1' then
            -- Counter-clockwise rotation -> Previous menu item
            if inmenu = '1' then
                if sel_item = 0 then
                    sel_item <= 3;
                else
                    sel_item <= sel_item - 1;
                end if;
            elsif ingamemode = '1' then
                if sel_item = 0 then
                    sel_item <= 2;
                else
                    sel_item <= sel_item - 1;
                end if;
            elsif inspeedmode = '1' then
                if sel_item = 0 then
                    sel_item <= 2;
                else
                    sel_item <= sel_item - 1;
                end if;
            end if;
        end if;

        -- Option selection / confirmation on rotary encoder push-button click
        if btn_click = '1' then
            if instartmode = '1' then
                instartmode <= '0';
                inmenu      <= '1';
                sel_item    <= 0;
            elsif inmenu = '1' then
                inmenu <= '0';
                case sel_item is
                    when 0 => -- Play
                        ingamemode <= '1';
                        sel_item   <= 0;
                    when 1 => -- Tutorial
                        intutorialmode <= '1';
                        sel_item       <= 0;
                    when 2 => -- Speed
                        inspeedmode <= '1';
                        sel_item    <= 1; -- Pre-select Medium speed
                    when 3 => -- Quit
                        inquitmode <= '1';
                        sel_item   <= 0;
                    when others =>
                        inmenu   <= '1';
                        sel_item <= 0;
                end case;
            elsif ingamemode = '1' then
                -- Game mode selection and launch
                case sel_item is
                    when 0 =>
                        choicemode <= 1;
                        choix_jeu  <= "01"; -- Classic mode
                    when 1 =>
                        choicemode <= 2;
                        choix_jeu  <= "10"; -- Zen mode
                    when 2 =>
                        choicemode <= 3;
                        choix_jeu  <= "11"; -- Arcade mode
                    when others =>
                        null;
                end case;
                confirmchoix1 <= '1';
                confirmchoix2 <= '1';
                ingamemode    <= '0';
                inmenu        <= '0'; -- Exit menu: active game displays on screen
                sel_item      <= 0;
            elsif inspeedmode = '1' then
                -- Speed setting configuration
                case sel_item is
                    when 0 =>
                        speedchoice <= 1;
                        choix_speed <= "01"; -- Slow
                    when 1 =>
                        speedchoice <= 2;
                        choix_speed <= "10"; -- Medium
                    when 2 =>
                        speedchoice <= 3;
                        choix_speed <= "11"; -- Fast
                    when others =>
                        null;
                end case;
                confirmchoix2 <= '1';
                inspeedmode   <= '0';
                inmenu        <= '1'; -- Return to main menu
                sel_item      <= 0;
            elsif intutorialmode = '1' then
                intutorialmode <= '0';
                inmenu         <= '1'; -- Return to main menu
                sel_item       <= 0;
            elsif inquitmode = '1' then
                inquitmode    <= '0';
                instartmode   <= '1'; -- Return to title screen
                confirmchoix1 <= '0';
                choix_jeu     <= "00";
                sel_item      <= 0;
            end if;
        end if;

    end if;
end process;

process(clk25, rst)
begin
    if rst = '0' then
        counter <= 0;
        clk1Hz <= '0';
    elsif rising_edge(clk25) then
        if counter = clk25MHz / 2 then -- Toggle state every 0.5 seconds (1 Hz blink rate)
            clk1Hz  <= not clk1Hz;
            counter <= 0;
        else
            counter <= counter + 1;
        end if;
    end if;
end process;

-- Synchronizer and Digital Debounce Filter for Rotary Encoder and Push-Button
process(clk25, rst)
    variable filter_A   : integer range 0 to 50000 := 0;
    variable filter_B   : integer range 0 to 50000 := 0;
    variable filter_btn : integer range 0 to 125000 := 0;
begin
    if rst = '0' then
        A_clean     <= '1';
        B_clean     <= '1';
        A_prev      <= '1';
        rot_cw      <= '0';
        rot_ccw     <= '0';
        rot_lockout <= 0;
        btn_clean   <= '1';
        btn_prev    <= '1';
        btn_click   <= '0';
        btn_lockout <= 0;
        filter_A    := 0;
        filter_B    := 0;
        filter_btn  := 0;
    elsif rising_edge(clk25) then
        rot_cw    <= '0';
        rot_ccw   <= '0';
        btn_click <= '0';

        -- Channel A digital debounce filter (switch1 = encoder_A) (50000 cycles = 2 ms at 25 MHz)
        if switch1 = '1' then
            if filter_A < 50000 then filter_A := filter_A + 1; else A_clean <= '1'; end if;
        else
            if filter_A > 0 then filter_A := filter_A - 1; else A_clean <= '0'; end if;
        end if;

        -- Channel B digital debounce filter (switch2 = encoder_B) (50000 cycles = 2 ms at 25 MHz)
        if switch2 = '1' then
            if filter_B < 50000 then filter_B := filter_B + 1; else B_clean <= '1'; end if;
        else
            if filter_B > 0 then filter_B := filter_B - 1; else B_clean <= '0'; end if;
        end if;

        -- Push-button digital debounce filter (switch3 = encoder_SW, active-low) (125000 cycles = 5 ms)
        if switch3 = '1' then
            if filter_btn < 125000 then filter_btn := filter_btn + 1; else btn_clean <= '1'; end if;
        else
            if filter_btn > 0 then filter_btn := filter_btn - 1; else btn_clean <= '0'; end if;
        end if;

        -- Rotary quadrature rotation detection with deadband rate-limiter
        if rot_lockout > 0 then
            rot_lockout <= rot_lockout - 1;
        else
            if A_prev = '1' and A_clean = '0' then
                if B_clean = '0' then
                    rot_cw      <= '1';
                    rot_lockout <= 1250000; -- ~50 ms rotation lockout
                else
                    rot_ccw     <= '1';
                    rot_lockout <= 1250000; -- ~50 ms rotation lockout
                end if;
            end if;
        end if;
        A_prev <= A_clean;

        -- Push-button falling edge detection (transition from '1' to '0')
        if btn_lockout > 0 then
            btn_lockout <= btn_lockout - 1;
        elsif btn_prev = '1' and btn_clean = '0' then
            btn_click   <= '1';
            btn_lockout <= 3750000; -- 150 ms anti-bounce / double-click lockout
        end if;
        btn_prev <= btn_clean;

    end if;
end process;

-- Internal selection bit decoding for sprite highlights
detected_switch1 <= '1' when (sel_item = 1 or sel_item = 3) else '0';
detected_switch2 <= '1' when (sel_item = 2 or sel_item = 3) else '0';



inSprite2 <= '1' when (to_integer(unsigned(x)) >= x_sprite2 and to_integer(unsigned(x)) < x_sprite2 + sprite_width and
                        to_integer(unsigned(y)) >= y_sprite2 and to_integer(unsigned(y)) < y_sprite2 + sprite_height and
                        clk1Hz = '1') 
             else '0';

inPlay <= '1' when (to_integer(unsigned(x)) >= x_play and to_integer(unsigned(x)) < x_play + sprite_width and
                    to_integer(unsigned(y)) >= y_play and to_integer(unsigned(y)) < y_play + sprite_height) 
          else '0';

inPlaySelect <= '1' when (to_integer(unsigned(x)) >= x_playselect and to_integer(unsigned(x)) < x_playselect + sprite_width and
                          to_integer(unsigned(y)) >= y_playselect and to_integer(unsigned(y)) < y_playselect + sprite_height) 
               else '0';

inTuto <= '1' when (to_integer(unsigned(x)) >= x_tuto and to_integer(unsigned(x)) < x_tuto + sprite_width and
                    to_integer(unsigned(y)) >= y_tuto and to_integer(unsigned(y)) < y_tuto + sprite_height) 
          else '0';

inTutoSelect <= '1' when (to_integer(unsigned(x)) >= x_tutoselect and to_integer(unsigned(x)) < x_tutoselect + sprite_width and
                          to_integer(unsigned(y)) >= y_tutoselect and to_integer(unsigned(y)) < y_tutoselect + sprite_height) 
                 else '0';

inSpeed <= '1' when (to_integer(unsigned(x)) >= x_speed and to_integer(unsigned(x)) < x_speed + sprite_width and
                     to_integer(unsigned(y)) >= y_speed and to_integer(unsigned(y)) < y_speed + sprite_height) 
           else '0';

inSpeedSelect <= '1' when (to_integer(unsigned(x)) >= x_speedselect and to_integer(unsigned(x)) < x_speedselect + sprite_width and
                           to_integer(unsigned(y)) >= y_speedselect and to_integer(unsigned(y)) < y_speedselect + sprite_height) 
                 else '0';

inQuit <= '1' when (to_integer(unsigned(x)) >= x_quit and to_integer(unsigned(x)) < x_quit + sprite_width and
                    to_integer(unsigned(y)) >= y_quit and to_integer(unsigned(y)) < y_quit + sprite_height) 
          else '0';

inQuitSelect <= '1' when (to_integer(unsigned(x)) >= x_quitselect and to_integer(unsigned(x)) < x_quitselect + sprite_width and
                          to_integer(unsigned(y)) >= y_quitselect and to_integer(unsigned(y)) < y_quitselect + sprite_height) 
                 else '0';
                 
inSpeedSlow <= '1' when (to_integer(unsigned(x)) >= x_speedslow and to_integer(unsigned(x)) < x_speedslow + sprite_width3 and
                          to_integer(unsigned(y)) >= y_speedslow and to_integer(unsigned(y)) < y_speedslow + sprite_height3) 
                 else '0';
                 
inSpeedFast <= '1' when (to_integer(unsigned(x)) >= x_speedfast and to_integer(unsigned(x)) < x_speedfast + sprite_width3 and
                          to_integer(unsigned(y)) >= y_speedfast and to_integer(unsigned(y)) < y_speedfast + sprite_height3) 
                 else '0';
                 
inSpeedMedium <= '1' when (to_integer(unsigned(x)) >= x_speedmedium and to_integer(unsigned(x)) < x_speedmedium + sprite_width3 and
                          to_integer(unsigned(y)) >= y_speedmedium and to_integer(unsigned(y)) < y_speedmedium + sprite_height3) 
                 else '0';
                 
inModeClassic <= '1' when (to_integer(unsigned(x)) >= x_modeclassic and to_integer(unsigned(x)) < x_modeclassic + sprite_width5 and
                          to_integer(unsigned(y)) >= y_modeclassic and to_integer(unsigned(y)) < y_modeclassic + sprite_height5) 
                 else '0';
                 
inModeArcade <= '1' when (to_integer(unsigned(x)) >= x_modearcade and to_integer(unsigned(x)) < x_modearcade + sprite_width5 and
                          to_integer(unsigned(y)) >= y_modearcade and to_integer(unsigned(y)) < y_modearcade + sprite_height5) 
                 else '0';
                 
inModeZen <= '1' when (to_integer(unsigned(x)) >= x_modezen and to_integer(unsigned(x)) < x_modezen + sprite_width5 and
                          to_integer(unsigned(y)) >= y_modezen and to_integer(unsigned(y)) < y_modezen + sprite_height5) 
                 else '0';
                 
inTutorial <= '1' when (to_integer(unsigned(x)) >= x_tutorial and to_integer(unsigned(x)) < x_tutorial + sprite_width5 and
                          to_integer(unsigned(y)) >= y_tutorial and to_integer(unsigned(y)) < y_tutorial + sprite_height5) 
                 else '0';


adr_sprite2 <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_sprite2) * sprite_width + (to_integer(unsigned(x)) - x_sprite2), 13));
adr_play <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_play) * sprite_width + (to_integer(unsigned(x)) - x_play), 13));
adr_playselect <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_playselect) * sprite_width + (to_integer(unsigned(x)) - x_playselect), 13));
adr_tuto <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_tuto) * sprite_width + (to_integer(unsigned(x)) - x_tuto), 13));
adr_tutoselect <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_tutoselect) * sprite_width + (to_integer(unsigned(x)) - x_tutoselect), 13));
adr_speed <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_speed) * sprite_width + (to_integer(unsigned(x)) - x_speed), 13));
adr_speedselect <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_speedselect) * sprite_width + (to_integer(unsigned(x)) - x_speedselect), 13));
adr_quit <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_quit) * sprite_width + (to_integer(unsigned(x)) - x_quit), 13));
adr_quitselect <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_quitselect) * sprite_width + (to_integer(unsigned(x)) - x_quitselect), 13));
adr_speedslow <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_speedslow) * sprite_width3 + (to_integer(unsigned(x)) - x_speedslow), 17));
adr_speedmedium <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_speedmedium) * sprite_width3 + (to_integer(unsigned(x)) - x_speedmedium), 17));
adr_speedfast <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_speedfast) * sprite_width3 + (to_integer(unsigned(x)) - x_speedfast), 17));
adr_modearcade <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_modearcade) * sprite_width5 + (to_integer(unsigned(x)) - x_modearcade), 16));
adr_modezen <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_modezen) * sprite_width5 + (to_integer(unsigned(x)) - x_modezen), 16));
adr_modeclassic <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_modeclassic) * sprite_width5 + (to_integer(unsigned(x)) - x_modeclassic), 16));
adr_tutorial <= std_logic_vector(to_unsigned((to_integer(unsigned(y)) - y_tutorial) * sprite_width5 + (to_integer(unsigned(x)) - x_tutorial), 16));


    -- Sprite Raster Rendering Pipeline
    process(clk25, inDisplayArea, inPlay, inPlaySelect, inTuto, inTutoSelect, inSpeedSelect, inQuitSelect, inSpeed, inQuit, color_play, color_tuto, color_speed, color_quit,
            color_pixel_sprite2, color_playselect, color_tutoselect, color_speedselect, color_quitselect, color_modeclassic, color_modezen, color_modearcade, color_speedslow,
            color_speedmedium, color_speedfast, color_tutorial, instartmode, inmenu, ingamemode, inspeedmode, intutorialmode, inSprite2, inModeClassic, inModeZen, inModeArcade,
            inSpeedSlow, inSpeedMedium, inSpeedFast, inTutorial, detected_switch1, detected_switch2)
    begin
        -- Default RGB assignment (black background) to avoid unintended latch inference
        r <= "0000";
        g <= "0000";
        b <= "0000";

        if inDisplayArea = '1' then
		   if instartmode = '1' then
              if inSprite2 ='1' then
                r <= (others => color_pixel_sprite2(2));
                g <= (others => color_pixel_sprite2(1));
                b <= (others => color_pixel_sprite2(0));
              end if;
		   elsif inmenu = '1' then
			  if (inPlay = '1' and not(detected_switch1 = '0' and detected_switch2 = '0')) then
				 r <= (others => color_play(2));
				 g <= (others => color_play(1));
				 b <= (others => color_play(0));
			  elsif inPlaySelect = '1' and (detected_switch1 = '0' and detected_switch2 = '0') then
				 r <= (others => color_playselect(2));
				 g <= (others => color_playselect(1));
				 b <= (others => color_playselect(0));
			  elsif (inTuto = '1' and not(detected_switch1 = '1' and detected_switch2 = '0')) then
				 r <= (others => color_tuto(2));
				 g <= (others => color_tuto(1));
				 b <= (others => color_tuto(0));
			  elsif inTutoSelect = '1' and (detected_switch1 = '1' and detected_switch2 = '0') then
				 r <= (others => color_tutoselect(2));
				 g <= (others => color_tutoselect(1));
				 b <= (others => color_tutoselect(0));
			  elsif (inSpeed = '1' and not(detected_switch1 = '0' and detected_switch2 = '1')) then
				 r <= (others => color_speed(2));
				 g <= (others => color_speed(1));
				 b <= (others => color_speed(0));
			  elsif inSpeedSelect = '1' and (detected_switch1 = '0' and detected_switch2 = '1') then
				 r <= (others => color_speedselect(2));
				 g <= (others => color_speedselect(1));
				 b <= (others => color_speedselect(0));
			  elsif (inQuit = '1' and not(detected_switch1 = '1' and detected_switch2 = '1')) then
				 r <= (others => color_quit(2));
				 g <= (others => color_quit(1));
				 b <= (others => color_quit(0));
			  elsif inQuitSelect = '1' and (detected_switch1 = '1' and detected_switch2 = '1') then
				 r <= (others => color_quitselect(2));
				 g <= (others => color_quitselect(1));
				 b <= (others => color_quitselect(0));
			  end if;
		   elsif ingamemode='1' then
			  if inModeClassic= '1' and detected_switch1 = '0' and detected_switch2 = '0' then
				 r <= (others => color_modeclassic(2));
				 g <= (others => color_modeclassic(1));
				 b <= (others => color_modeclassic(0));
			  elsif inModeZen= '1' and detected_switch1 = '1' and detected_switch2 = '0' then
				 r <= (others => color_modezen(2));
				 g <= (others => color_modezen(1));
				 b <= (others => color_modezen(0));
			  elsif inModeArcade= '1' and detected_switch1 = '0' and detected_switch2 = '1'then
				 r <= (others => color_modearcade(2));
				 g <= (others => color_modearcade(1));
				 b <= (others => color_modearcade(0));
			  end if;
		   elsif inspeedmode='1' then
			  if inSpeedSlow= '1' and detected_switch1 = '0' and detected_switch2 = '0' then
				 r <= (others => color_speedslow(2));
				 g <= (others => color_speedslow(1));
				 b <= (others => color_speedslow(0));
			  elsif inSpeedMedium= '1' and detected_switch1 = '1' and detected_switch2 = '0' then
				 r <= (others => color_speedmedium(2));
				 g <= (others => color_speedmedium(1));
				 b <= (others => color_speedmedium(0));
			  elsif inSpeedFast= '1' and detected_switch1 = '0' and detected_switch2 = '1'then
				 r <= (others => color_speedfast(2));
				 g <= (others => color_speedfast(1));
				 b <= (others => color_speedfast(0));
			  end if;
		   elsif intutorialmode='1' then
			  if inTutorial= '1' then
				 r <= (others => color_tutorial(2));
				 g <= (others => color_tutorial(1));
				 b <= (others => color_tutorial(0));
			  end if;
		   end if;
        end if;
		  
    end process;

end Behavioral;