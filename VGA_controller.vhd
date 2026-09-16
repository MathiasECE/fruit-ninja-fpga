--------------------------------------------------------------------------------
-- Module Name: VGA_controller - Behavioral
-- Description: Core Fruit Ninja Game Controller & Video Processor.
--              Features:
--              - Parabolic projectile physics for multiple simultaneous fruit/bomb sprites.
--              - Rotary blade angle control (-55 to +55 deg) via fixed-point tangent table.
--              - Ultrasonic distance sensor integration for vertical blade position (height).
--              - Line-box collision intersection detection & push-button strike latching.
--              - Multi-slice pomegranate mechanics, combo multipliers, and score tracking.
--              - Classic (3 lives), Zen (timer), and Arcade game modes.
--              - VGA raster generation with 1-pixel ultra-sharp blade rendering.
-- Target Board: Intel DE10-Lite (MAX 10 FPGA)
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity VGA_controller is
    generic (
        sprite_width  : integer := 64;     -- Width of fruit/bomb sprites in pixels
        sprite_height : integer := 32;     -- Height of fruit/bomb sprites in pixels
        screen_width  : integer := 640;    -- VGA visible area width in pixels
        screen_height : integer := 480     -- VGA visible area height in pixels
    );
    port (
        clk25               : in  std_logic;                    -- 25 MHz pixel clock
        clkfruit            : in  std_logic;                    -- Fruit animation clock trigger
        rst                 : in  std_logic;                    -- Global reset (active-low: '0')
        boutton             : in  std_logic;                    -- Physical strike push-button (active-low: '0')
        rnd_byte            : in  std_logic_vector(7 downto 0); -- Pseudo-random byte from LFSR
        frame               : in  std_logic;                    -- Vertical blanking sync pulse
        inDisplayArea       : in  std_logic;                    -- Active display area flag
        px, py              : in  std_logic_vector(9 downto 0); -- Current VGA raster coordinates
        color_pixel_sprite1 : in  std_logic_vector(2 downto 0); -- ROM pixel colors (3-bit RGB)
        color_pixel_sprite2 : in  std_logic_vector(2 downto 0);
        color_pixel_sprite3 : in  std_logic_vector(2 downto 0);
        color_pixel_sprite4 : in  std_logic_vector(2 downto 0);
        color_pixel_sprite5 : in  std_logic_vector(2 downto 0);
        color_pixel_sprite6 : in  std_logic_vector(2 downto 0);
        mode                : in  std_logic_vector(1 downto 0); -- Game mode ("00"=Idle, "01"=Classic, "10"=Zen, "11"=Arcade)
        PlusDeVie           : in  std_logic;                    -- Life loss pulse
        Distance            : in  std_logic_vector(13 downto 0);-- Ultrasonic sensor distance reading (mm)
        Entree_Angle        : in  std_logic_vector(4 downto 0); -- Rotary encoder angle index (0 to 18)
        vitesse             : in  std_logic_vector(1 downto 0); -- Speed preset ("01"=Slow, "10"=Medium, "11"=Fast)
        r, g, b             : out std_logic_vector(3 downto 0); -- 12-bit VGA RGB color bus
        adr_sprite1         : out std_logic_vector(10 downto 0);-- ROM sprite address lines
        adr_sprite2         : out std_logic_vector(10 downto 0);
        adr_sprite3         : out std_logic_vector(10 downto 0);
        adr_sprite4         : out std_logic_vector(10 downto 0);
        adr_sprite5         : out std_logic_vector(10 downto 0);
        adr_sprite6         : out std_logic_vector(10 downto 0);
        rstTimer            : out std_logic;                    -- Timer reset control
        TimerActif          : out std_logic;                    -- Timer active enable
        rstVie              : out std_logic;                    -- Life counter reset control
        VieActive           : out std_logic;                    -- Life counter active enable
        suprVie             : out std_logic;                    -- Life decrement trigger
        nb_points           : out std_logic_vector(13 downto 0);-- 14-bit binary score output
        selection           : out std_logic                     -- Display select signal
    );
end VGA_controller;

architecture Behavioral of VGA_controller is
    constant MAX_SPRITES : integer := 13;  
    signal inSprite1, inSprite2, inSprite3, inSprite4, inSprite5, inSprite6 : std_logic;
    signal nb_sprite        : integer := 0;
    signal nb_bombe         : integer := 0;
    signal nb_fruit         : integer := 0;
    signal tempclkfruit     : std_logic := '0';
    signal vie              : integer := 0;
    signal FruitCoupe       : integer := 0;
    signal Pause            : integer := 0;
    signal BlindageBoutton  : std_logic := '0';
    signal Points           : integer := 0;

    -- Sprite descriptor record for physics and rendering
    type sprite_t is record
        x          : integer range -200 to 1023;  -- X coordinate
        y          : integer range -200 to 1023;  -- Y coordinate
        vx         : integer range -15 to 15;    -- Horizontal velocity
        vy         : integer range -15 to 15;    -- Vertical initial velocity
        t          : integer range 0 to 511;      -- Flight time (used for gravity acceleration)
        choixImage : integer range 0 to 7;        -- Sprite image selection index
        afficher   : integer range 0 to 1;        -- Active/visible flag (1 = active, 0 = inactive pool slot)
        bombe      : integer range 0 to 1;        -- Bomb flag
        grenade    : integer range 0 to 1;        -- Pomegranate (multi-slice) flag
        nb_decoupe : integer range 0 to 31;       -- Slices count for pomegranate
    end record;

    type sprite_array_t is array (0 to MAX_SPRITES - 1) of sprite_t;
    signal sprites : sprite_array_t;
    
    -- Tangent lookup table for blade angles (values scaled by 1024 for fixed-point math)
    -- Symmetric angle table centered horizontally (index 9 = 0 degrees)
    -- Indices 0 to 8   : Negative angles (-55 deg to -2 deg, blade tilts downward)
    -- Index 9          : Zero angle (0 deg, perfectly horizontal blade)
    -- Indices 10 to 18 : Positive angles (+2 deg to +55 deg, blade tilts upward)
    type tan_table_t is array (0 to 18) of integer;
    constant tan_table : tan_table_t := (
        0  => -1462, -- -55 degrees: tan(-55) * 1024
        1  => -1137, -- -48 degrees
        2  =>  -880, -- -41 degrees
        3  =>  -665, -- -33 degrees
        4  =>  -477, -- -25 degrees
        5  =>  -320, -- -17 degrees
        6  =>  -190, -- -10 degrees
        7  =>   -90, --  -5 degrees
        8  =>   -35, --  -2 degrees
        9  =>     0, --   0 degrees (PERFECTLY HORIZONTAL)
        10 =>    35, --  +2 degrees
        11 =>    90, --  +5 degrees
        12 =>   190, -- +10 degrees
        13 =>   320, -- +17 degrees
        14 =>   477, -- +25 degrees
        15 =>   665, -- +33 degrees
        16 =>   880, -- +41 degrees
        17 =>  1137, -- +48 degrees
        18 =>  1462  -- +55 degrees
    );
    signal angle_cut     : integer range 0 to 18 := 9;
    signal height_cut    : integer := 350;
    signal target_height : integer := 350;
    signal btn_strike    : std_logic := '0';
    
begin
    process(clk25, rst)
        variable sprite_cut_y : integer;
        variable sprite_cut_y1 : integer;
        variable y_left, y_right : integer;
        variable y_min, y_max : integer;
        variable is_intersecting : boolean;
        variable is_cut : boolean;
        variable strike_active : boolean;
        variable supprimer : integer;
        variable sprites_var : sprite_array_t;
        variable tempNb_sprite  : integer;
        variable tempsuprVie  : std_logic;
        variable tempFruitCoupe  : integer;
        variable tempnb_fruit  : integer;
        variable tempnb_bombe  : integer;
        variable tempPoints  : integer;
        variable decoupeEnMemeTemp  : integer;
        variable empty_slot : integer range 0 to MAX_SPRITES;
        variable filter_ticker : integer range 0 to 416666 := 0;
    begin 
        if rst = '0' then
            for i in 0 to MAX_SPRITES - 1 loop
                sprites(i).x <= 10;
                sprites(i).y <= -100;
                sprites(i).vx <= 0;
                sprites(i).vy <= 0;
                sprites(i).t <= 0; 
                sprites(i).afficher <= 0;					
                sprites(i).choixImage <= 0;
                sprites(i).nb_decoupe <= 0;
            end loop;
            -- Height and game state initialization
            height_cut    <= 350;
            target_height <= 350;
            vie           <= 3;
            FruitCoupe    <= 0;
            Points        <= 0;
            nb_points     <= (others => '0');
            nb_sprite     <= 0;
            rstTimer      <= '1';
            Timeractif    <= '0';
            rstVie        <= '1';
            VieActive     <= '0';
            Pause         <= 0;
            btn_strike    <= '0';
            
        elsif rising_edge(clk25) then
            -- High-speed 25 MHz edge latch for physical strike button to never miss a slice
            if boutton = '0' then
                btn_strike <= '1';
            end if;

            -- IIR low-pass filter on vertical blade height to smooth hand jitter
            if filter_ticker = 416666 then
                height_cut    <= height_cut + ((target_height - height_cut) / 4);
                filter_ticker := 0;
            else
                filter_ticker := filter_ticker + 1;
            end if;
            
            if frame = '1' then
                -- Slicing is active exclusively when player strikes using the button
                strike_active := (boutton = '0') or (btn_strike = '1');
                btn_strike    <= '0'; -- Clear button latch for upcoming frame
                if (clkfruit = '1' and tempclkfruit = '0' and pause = 0 and mode /= "00") then 
                
                    -- Find an available inactive slot in the sprite object pool
                    empty_slot := MAX_SPRITES;
                    for k in 0 to MAX_SPRITES - 1 loop
                        if sprites(k).afficher = 0 then
                            empty_slot := k;
                            exit;
                        end if;
                    end loop;
                
                    -- Spawn bomb sprite (probabilistic spawn with max 2 concurrent bombs)
                    if (rnd_byte(5 downto 4) = "01") and (nb_bombe < 3) and (empty_slot < MAX_SPRITES) then
                        if rnd_byte(7) = '0' then
                            sprites(empty_slot).x <= to_integer(unsigned(rnd_byte));
                        else
                            sprites(empty_slot).x <= 255 + to_integer(unsigned(rnd_byte)); 
                        end if;

                        if rnd_byte(4) = '0' then
                            if vitesse = "01" then sprites(empty_slot).vx <= 2;																		
                            elsif vitesse = "10" then sprites(empty_slot).vx <= 4;
                            elsif vitesse = "11" then sprites(empty_slot).vx <= 6;
                            end if;
                        else
                            if vitesse = "01" then sprites(empty_slot).vx <= -2;
                            elsif vitesse = "10" then sprites(empty_slot).vx <= -4;
                            elsif vitesse = "11" then sprites(empty_slot).vx <= -6;
                            end if;
                        end if;

                        sprites(empty_slot).choixImage <= 5; 
                        sprites(empty_slot).y <= screen_height - sprite_height; 
                        
                        if vitesse = "01" then sprites(empty_slot).vy <= 7;
                        elsif vitesse = "10" then sprites(empty_slot).vy <= 9;
                        elsif vitesse = "11" then sprites(empty_slot).vy <= 10;
                        end if;									
                        
                        sprites(empty_slot).t <= 0;
                        sprites(empty_slot).afficher <= 1;
                        sprites(empty_slot).bombe <= 1;
                        sprites(empty_slot).grenade <= 0;
                        nb_bombe <= nb_bombe + 1;
                        nb_sprite <= nb_sprite + 1;
                        
                    -- Spawn fruit sprite (up to 9 concurrent fruits)
                    elsif nb_fruit < 10 and empty_slot < MAX_SPRITES then
                        if rnd_byte(7) = '0' then
                            sprites(empty_slot).x <= to_integer(unsigned(rnd_byte));
                        else
                            sprites(empty_slot).x <= 255 + to_integer(unsigned(rnd_byte)); 
                        end if;
                        
                        if rnd_byte(4) = '0' then
                            if vitesse = "01" then sprites(empty_slot).vx <= 2;																		
                            elsif vitesse = "10" then sprites(empty_slot).vx <= 4;
                            elsif vitesse = "11" then sprites(empty_slot).vx <= 6;
                            end if;
                        else
                            if vitesse = "01" then sprites(empty_slot).vx <= -2;
                            elsif vitesse = "10" then sprites(empty_slot).vx <= -4;
                            elsif vitesse = "11" then sprites(empty_slot).vx <= -6;
                            end if;
                        end if;

                        -- Special bonus pomegranate spawn after 20 cut fruits
                        if FruitCoupe >= 20 then
                            sprites(empty_slot).choixImage <= 4;
                            sprites(empty_slot).grenade <= 1;
                            FruitCoupe <= 0;
                        else
                            sprites(empty_slot).choixImage <= to_integer(unsigned(rnd_byte(1 downto 0)));
                            sprites(empty_slot).grenade <= 0;
                        end if;
                        
                        sprites(empty_slot).y <= screen_height - sprite_height;            
                        if vitesse = "01" then sprites(empty_slot).vy <= 7;
                        elsif vitesse = "10" then sprites(empty_slot).vy <= 9;
                        elsif vitesse = "11" then sprites(empty_slot).vy <= 10;
                        end if;	
                        
                        sprites(empty_slot).t <= 0;
                        sprites(empty_slot).afficher <= 1;
                        sprites(empty_slot).bombe <= 0;
                        nb_fruit <= nb_fruit + 1;
                        nb_sprite <= nb_sprite + 1;
                    end if;
                else
                    
                    -- Ultrasonic distance-to-screen coordinate mapping (20 mm to 400 mm)
                    if to_integer(unsigned(Distance)) >= 20 and to_integer(unsigned(Distance)) <= 400 then
                        if to_integer(unsigned(Distance)) >= 340 then
                            target_height <= 0; -- Hand distant: blade at screen top
                        else
                            target_height <= 480 - ((3 * (to_integer(unsigned(Distance)) - 20)) / 2);
                        end if;
                    end if;
                    
                    if to_integer(unsigned(Entree_Angle)) <= 18 then
                        angle_cut <= to_integer(unsigned(Entree_Angle));
                    else
                        angle_cut <= 18;
                    end if;
                
                    -- Mode decoder: control life counters, timers, and display mux
                    if mode = "01" then 
                        rstTimer <= '1'; Timeractif <= '0'; rstVie <='0'; VieActive <= '1'; selection <= '1';
                    elsif mode = "10" then 
                        rstTimer <= '0'; Timeractif <= '1'; rstVie <='1'; VieActive <= '0'; selection <= '0';
                    elsif mode = "11" then 
                        rstTimer <= '0'; Timeractif <= '1'; rstVie <='1'; VieActive <= '0'; selection <= '0';
                    else
                        rstTimer <= '1'; Timeractif <= '0'; rstVie <='1'; VieActive <= '0'; selection <= '1';
                    end if;
                    
                    suprVie <= '0';
                    
                    -- Slicing collision detection: line-box intersection
                    supprimer := 0;
                    for i in 0 to MAX_SPRITES - 1 loop 
                        if sprites(i).afficher = 1 then
                            y_left  := height_cut - ((tan_table(angle_cut) * sprites(i).x) / 1024);
                            y_right := height_cut - ((tan_table(angle_cut) * (sprites(i).x + sprite_width)) / 1024);
                            if y_left < y_right then
                                y_min := y_left;
                                y_max := y_right;
                            else
                                y_min := y_right;
                                y_max := y_left;
                            end if;

                            is_intersecting := (y_min <= sprites(i).y + sprite_height) and 
                                               (y_max >= sprites(i).y) and 
                                               (sprites(i).y >= 0) and 
                                               (sprites(i).y <= 480);

                            is_cut := is_intersecting and strike_active;

                            if (sprites(i).y > 500) or is_cut then
                                if sprites(i).grenade = 1 and is_cut then
                                    pause <= 1;
                                    sprites(i).nb_decoupe <= sprites(i).nb_decoupe + 1;
                                    
                                    if (sprites(i).nb_decoupe >= 20) then
                                        sprites(i).nb_decoupe <= 0;
                                        Pause <= 0;
                                        supprimer := 1;
                                        exit;
                                    end if;
                                else
                                    supprimer := 1;
                                    exit;
                                end if;
                            end if;
                        end if;
                    end loop;
                    BlindageBoutton <= boutton;

                    -- Process sprite deletion, scoring, and life decrement
                    if supprimer = 1 then
                        sprites_var := sprites;
                        tempNb_sprite := nb_sprite;
                        tempnb_bombe := nb_bombe;
                        tempnb_fruit := nb_fruit;
                        tempsuprVie := suprVie;
                        tempFruitCoupe := FruitCoupe;
                        decoupeEnMemeTemp := 0;
                        tempPoints := Points;

                        for i in (MAX_SPRITES - 1) downto 0 loop  
                            if sprites_var(i).afficher = 1 then
                                y_left  := height_cut - ((tan_table(angle_cut) * sprites_var(i).x) / 1024);
                                y_right := height_cut - ((tan_table(angle_cut) * (sprites_var(i).x + sprite_width)) / 1024);
                                if y_left < y_right then
                                    y_min := y_left;
                                    y_max := y_right;
                                else
                                    y_min := y_right;
                                    y_max := y_left;
                                end if;

                                is_intersecting := (y_min <= sprites_var(i).y + sprite_height) and 
                                                   (y_max >= sprites_var(i).y) and 
                                                   (sprites_var(i).y >= 0) and 
                                                   (sprites_var(i).y <= 480);

                                is_cut := is_intersecting and strike_active;

                                if (sprites_var(i).y > 500) or is_cut then
                                    
                                    if sprites_var(i).bombe = 1 then
                                        tempnb_bombe := tempnb_bombe - 1;
                                    else
                                        tempnb_fruit := tempnb_fruit - 1;
                                    end if;

                                    -- Fruit dropped below screen in Classic mode triggers life loss
                                    if sprites_var(i).y > 500 and mode = "01" and sprites_var(i).bombe = 0 then
                                        tempsuprVie := '1';
                                    end if;

                                    if is_cut then
                                        tempFruitCoupe := tempFruitCoupe + 1;
                                    end if;

                                    -- Deactivate sprite in-place inside the object pool
                                    sprites_var(i).afficher := 0;
                                    sprites_var(i).y := -100;
                                    sprites_var(i).x := 10;
                                    sprites_var(i).vx := 0;
                                    sprites_var(i).vy := 0;
                                    sprites_var(i).t := 0; 
                                    
                                    tempNb_sprite := tempNb_sprite - 1;
                                    if sprites_var(i).bombe = 0 and is_cut then
                                        decoupeEnMemeTemp := decoupeEnMemeTemp + 1;
                                    end if;
                                    
                                    -- Scoring rules for fruits and bombs
                                    if is_cut and sprites_var(i).bombe = 0 then
                                        tempPoints := tempPoints + 1;
                                    elsif is_cut and sprites_var(i).bombe = 1 then
                                        if mode = "11" then -- Arcade mode: -10 points penalty
                                            tempPoints := tempPoints - 10;
                                            if tempPoints < 0 then
                                                tempPoints := 0;
                                            end if;
                                        elsif mode = "01" then -- Classic mode: bomb causes life loss
                                            tempsuprVie := '1';
                                        end if;
                                    end if;
                                end if;
                            end if;
                        end loop; 
                        
                        -- Combo bonuses for simultaneous cuts
                        if decoupeEnMemeTemp >= 3  then
                            tempPoints := tempPoints + decoupeEnMemeTemp*2;
                        elsif decoupeEnMemeTemp >= tempnb_fruit + 1 and tempnb_bombe >= 1  then
                            tempPoints := tempPoints + 10;
                        end if;
                        
                        sprites    <= sprites_var;
                        Nb_sprite  <= tempNb_sprite;
                        nb_bombe   <= tempnb_bombe;
                        nb_fruit   <= tempnb_fruit;
                        suprVie    <= tempsuprVie;
                        FruitCoupe <= tempFruitCoupe;
                        Points     <= tempPoints;
                        nb_points  <= std_logic_vector(to_unsigned(tempPoints, 14));

                    else	
                        -- Update parabolic projectile physics (gravity: vy - t/7)
                        if Pause = 0 then
                            for i in 0 to MAX_SPRITES - 1 loop  
                                if sprites(i).afficher = 1 then
                                    sprites(i).t <= sprites(i).t + 1;
                                    sprites(i).x <= sprites(i).x + sprites(i).vx;
                                    sprites(i).y <= sprites(i).y - sprites(i).vy + (sprites(i).t / 7);
                                    
                                    -- Wall bounce boundary checking: reverse horizontal speed vx
                                    if sprites(i).x >= screen_width - sprite_width then
                                        if vitesse = "01" then sprites(i).vx <= -2;																		
                                        elsif vitesse = "10" then sprites(i).vx <= -4;
                                        elsif vitesse = "11" then sprites(i).vx <= -6;
                                        end if;
                                    elsif sprites(i).x <= 0 then
                                        if vitesse = "01" then sprites(i).vx <= 2;																		
                                        elsif vitesse = "10" then sprites(i).vx <= 4;
                                        elsif vitesse = "11" then sprites(i).vx <= 6;
                                        end if;
                                    end if;
                                end if;
                            end loop;  
                        end if;
                    end if;
                end if;
                tempclkfruit <= clkfruit;
            end if;
        end if;
    end process;

    -- Sprite ROM Address Generation Pipeline
    process(px, py, sprites)
    begin
        inSprite1   <= '0';
        inSprite2   <= '0';
        inSprite3   <= '0';
        inSprite4   <= '0';
        inSprite5   <= '0';
        inSprite6   <= '0';
        adr_sprite1 <= (others => '0');
        adr_sprite2 <= (others => '0');
        adr_sprite3 <= (others => '0');
        adr_sprite4 <= (others => '0');
        adr_sprite5 <= (others => '0');
        adr_sprite6 <= (others => '0');

        for i in 0 to MAX_SPRITES - 1 loop
            if sprites(i).afficher = 1 then
                if (to_integer(unsigned(px)) >= sprites(i).x and 
                    to_integer(unsigned(px)) < sprites(i).x + sprite_width and
                    to_integer(unsigned(py)) >= sprites(i).y and 
                    to_integer(unsigned(py)) < sprites(i).y + sprite_height) then
                    
                    if sprites(i).choixImage = 0 then
                        inSprite1   <= '1';
                        adr_sprite1 <= std_logic_vector(to_unsigned((to_integer(unsigned(py)) - sprites(i).y) * sprite_width + 
                                                                     (to_integer(unsigned(px)) - sprites(i).x), 11));
                    elsif sprites(i).choixImage = 1 then
                        inSprite2   <= '1';
                        adr_sprite2 <= std_logic_vector(to_unsigned((to_integer(unsigned(py)) - sprites(i).y) * sprite_width + 
                                                                     (to_integer(unsigned(px)) - sprites(i).x), 11));
                    elsif sprites(i).choixImage = 2 then
                        inSprite3   <= '1';
                        adr_sprite3 <= std_logic_vector(to_unsigned((to_integer(unsigned(py)) - sprites(i).y) * sprite_width + 
                                                                     (to_integer(unsigned(px)) - sprites(i).x), 11));
                    elsif sprites(i).choixImage = 3 then
                        inSprite4   <= '1';
                        adr_sprite4 <= std_logic_vector(to_unsigned((to_integer(unsigned(py)) - sprites(i).y) * sprite_width + 
                                                                     (to_integer(unsigned(px)) - sprites(i).x), 11));
                    elsif sprites(i).choixImage = 4 then
                        inSprite5   <= '1';
                        adr_sprite5 <= std_logic_vector(to_unsigned((to_integer(unsigned(py)) - sprites(i).y) * sprite_width + 
                                                                     (to_integer(unsigned(px)) - sprites(i).x), 11));
                    elsif sprites(i).choixImage = 5 then
                        inSprite6   <= '1';
                        adr_sprite6 <= std_logic_vector(to_unsigned((to_integer(unsigned(py)) - sprites(i).y) * sprite_width + 
                                                                     (to_integer(unsigned(px)) - sprites(i).x), 11));															  
                    end if;
                    exit;
                end if;
            end if;
        end loop;
    end process;

    -- Final Pixel RGB Raster Output Multiplexer
    -- Priority: 1. Ultra-sharp red blade raster line (1 pixel)
    --           2. Active fruit/bomb sprite pixels from ROM
    --           3. Background color (black)
    process(px, py, angle_cut, height_cut, inDisplayArea, inSprite1, inSprite2, inSprite3, inSprite4, inSprite5, inSprite6, color_pixel_sprite1, color_pixel_sprite2, color_pixel_sprite3, color_pixel_sprite4, color_pixel_sprite5, color_pixel_sprite6)
        variable slope  : integer;
        variable y_line : integer;
        variable py_val : integer;
    begin
        slope   := tan_table(angle_cut);
        y_line  := height_cut - ((slope * to_integer(unsigned(px))) / 1024);
        py_val  := to_integer(unsigned(py));
        
        if inDisplayArea = '1' then
            -- Single-pixel ultra-sharp red blade raster line
            if py_val = y_line then
                r <= "1111"; 
                g <= "0000";
                b <= "0000";
            elsif inSprite1 = '1' then
                r <= (others => color_pixel_sprite1(2));
                g <= (others => color_pixel_sprite1(1));
                b <= (others => color_pixel_sprite1(0));
            elsif inSprite2 = '1' then
                r <= (others => color_pixel_sprite2(2));
                g <= (others => color_pixel_sprite2(1));
                b <= (others => color_pixel_sprite2(0));
            elsif inSprite3 = '1' then
                r <= (others => color_pixel_sprite3(2));
                g <= (others => color_pixel_sprite3(1));
                b <= (others => color_pixel_sprite3(0));
            elsif inSprite4 = '1' then
                r <= (others => color_pixel_sprite4(2));
                g <= (others => color_pixel_sprite4(1));
                b <= (others => color_pixel_sprite4(0));
            elsif inSprite5 = '1' then
                r <= (others => color_pixel_sprite5(2));
                g <= (others => color_pixel_sprite5(1));
                b <= (others => color_pixel_sprite5(0));
            elsif inSprite6 = '1' then
                r <= (others => color_pixel_sprite6(2));
                g <= (others => color_pixel_sprite6(1));
                b <= (others => color_pixel_sprite6(0));
            else
                r <= "0000";
                g <= "0000";
                b <= "0000";
            end if;
        else
            r <= "0000";
            g <= "0000";
            b <= "0000";
        end if;
    end process;
end Behavioral;