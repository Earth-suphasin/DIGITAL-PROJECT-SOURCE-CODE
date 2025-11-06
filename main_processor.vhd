library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity game_display is
    Port (
        clk25    : in  std_logic;
        data_in  : in  std_logic_vector(7 downto 0); -- Input จาก Player 1
        data_in2 : in  std_logic_vector(7 downto 0); -- Input จาก Player 2
        vga_r, vga_g, vga_b : out std_logic;
        hsync, vsync : out std_logic;
        
        -- HIT DETECTION OUTPUTS (P126 / P131)
        hit_p1_out : out std_logic;
        hit_p2_out : out std_logic;
        
        -- GAME OVER SYNC OUTPUTS (P133 / P137)
        game_over_p1_out : out std_logic;
        game_over_p2_out : out std_logic
    );
end game_display;

architecture Behavioral of game_display is

    -- INTERNAL HIT SIGNALS (3-cycle pulse logic)
    signal s_raw_hit_p1, s_raw_hit_p2 : std_logic := '0';
    signal hit_delay1_p1, hit_delay2_p1 : std_logic := '0';
    signal hit_delay1_p2, hit_delay2_p2 : std_logic := '0';
    signal s_hit_p1, s_hit_p2 : std_logic := '0'; 
    
    -- INTERNAL GAME OVER SYNC SIGNALS
    signal s_game_over_p1 : std_logic := '0';
    signal s_game_over_p2 : std_logic := '0';

    ----------------------------------------------------------------------
    -- VGA Timing
    ----------------------------------------------------------------------
    signal h_count, v_count : integer range 0 to 799 := 0;
    signal h_active, v_active : std_logic;

    ----------------------------------------------------------------------
    -- Color Definitions (1-bit per color)
    ----------------------------------------------------------------------
    constant C_BLACK     : std_logic_vector(2 downto 0) := "000";
    constant C_DARK_GRAY : std_logic_vector(2 downto 0) := "001";
    constant C_RED       : std_logic_vector(2 downto 0) := "100"; 
    constant C_GREEN     : std_logic_vector(2 downto 0) := "010"; 
    constant C_YELLOW    : std_logic_vector(2 downto 0) := "110";
    constant C_CYAN      : std_logic_vector(2 downto 0) := "011";
    constant C_WHITE     : std_logic_vector(2 downto 0) := "111";

    ----------------------------------------------------------------------
    -- Game State Logic
    ----------------------------------------------------------------------
    type t_game_state is (STATE_PLAYING, STATE_GAME_OVER);
    signal game_state : t_game_state := STATE_PLAYING;
    signal winner_p1 : std_logic := '0';
    signal winner_p2 : std_logic := '0';

    -- RESTART CONTROL FLAG (Edge-Sensitive Logic)
    signal fire_buttons_released : std_logic := '0'; 

    ----------------------------------------------------------------------
    -- Player & Bullet Data
    ----------------------------------------------------------------------
    constant PLAYER_SIZE : integer := 20;
    subtype t_coord is integer range 0 to 639;
    
    signal x1_pos, y1_pos : t_coord := 200;
    signal x2_pos, y2_pos : t_coord := 420;
    -- facing: 0:Up, 1:Down, 2:Left, 3:Right
    signal facing1, facing2 : integer range 0 to 3 := 3; 

    constant MAX_X_POS : integer := 640 - PLAYER_SIZE; 
    constant MAX_Y_POS : integer := 480 - PLAYER_SIZE;

    type bullet_t is record x, y : integer range -16 to 655; active : std_logic; dir : integer range 0 to 3; end record;
    type bullet_array_t is array (0 to 7) of bullet_t;
    signal bullets1, bullets2 : bullet_array_t := (others => (x=>-16, y=>0, active=>'0', dir=>0));
    signal bullet_index1, bullet_index2 : integer range 0 to 7 := 0;
    constant FIRE_COOLDOWN_MAX : integer := 60; -- Increased Cooldown
    signal fire_cooldown1, fire_cooldown2 : integer range 0 to FIRE_COOLDOWN_MAX := 0;

    ----------------------------------------------------------------------
    -- HP system
    ----------------------------------------------------------------------
    constant MAX_HP : integer := 100;
    signal hp1, hp2 : integer range 0 to MAX_HP := MAX_HP;

    ----------------------------------------------------------------------
    -- Input
    ----------------------------------------------------------------------
    signal btn_up, btn_down, btn_left, btn_right, btn_fire, ready_flag : std_logic;
    signal btn2_up, btn2_down, btn2_left, btn2_right, btn2_fire, ready2_flag : std_logic;

    constant MOVE_DIV_MAX : integer := 200000;
    signal move_div : integer range 0 to MOVE_DIV_MAX := 0;
    
    signal next_vga_r, next_vga_g, next_vga_b : std_logic := '0';

    -- --------------------------------------------------------------------
    -- Text/UI Constants
    -- --------------------------------------------------------------------
    constant CHAR_WIDTH  : integer := 8; constant CHAR_HEIGHT : integer := 8;
    constant CHAR_SPACING : integer := 2; constant UI_TOP_MARGIN : integer := 30; 
    constant GO_CHAR_TOTAL : integer := 9; 
    constant GO_TOTAL_DRAW_WIDTH : integer := (GO_CHAR_TOTAL * CHAR_WIDTH) + ((GO_CHAR_TOTAL - 1) * CHAR_SPACING);
    constant W_CHAR_TOTAL : integer := 7;
    constant W_TOTAL_DRAW_WIDTH : integer := (W_CHAR_TOTAL * CHAR_WIDTH) + ((W_CHAR_TOTAL - 1) * CHAR_SPACING);

    constant GO_START_X : integer := 320 - (GO_TOTAL_DRAW_WIDTH / 2); constant GO_START_Y : integer := 200;
    constant W_START_X : integer := 320 - (W_TOTAL_DRAW_WIDTH / 2); constant W_START_Y : integer := 260;
    constant HP_BAR_Y_START : integer := 10 + UI_TOP_MARGIN; constant HP_BAR_Y_END : integer := 19 + UI_TOP_MARGIN;

    constant P1_BAR_LEFT_X : integer := 15; constant P1_BAR_RIGHT_X : integer := 217; 
    constant HP1_TEXT_START_X : integer := P1_BAR_LEFT_X + 1; constant HP1_TEXT_START_Y : integer := HP_BAR_Y_START - CHAR_HEIGHT - 2; 
    constant P1_NAME_TEXT_START_X : integer := P1_BAR_LEFT_X + 1; constant P1_NAME_TEXT_START_Y : integer := HP_BAR_Y_END + 2; 

    constant P2_BAR_RIGHT_X : integer := 625; constant P2_BAR_LEFT_X : integer := 640 - 217;
    constant HP2_TEXT_START_X : integer := P2_BAR_RIGHT_X - (2 * CHAR_WIDTH + CHAR_SPACING) - 1; constant HP2_TEXT_START_Y : integer := HP_BAR_Y_START - CHAR_HEIGHT - 2; 
    constant P2_NAME_TEXT_START_X : integer := P2_BAR_RIGHT_X - (2 * CHAR_WIDTH + CHAR_SPACING) - 1; constant P2_NAME_TEXT_START_Y : integer := HP_BAR_Y_END + 2; 

    -- SPRITE CONSTANTS
    constant BULLET_SPRITE_WIDTH  : integer := 4; constant BULLET_SPRITE_HEIGHT : integer := 4;
    type t_mask_4x4 is array (0 to 3) of std_logic_vector(3 downto 0);
    constant FIREBALL_MASK : t_mask_4x4 := (0 => "0110", 1 => "1111", 2 => "1111", 3 => "0110");

    constant PLAYER_SPRITE_WIDTH  : integer := 20; constant PLAYER_SPRITE_HEIGHT : integer := 20;
    type t_mask_20x20 is array (0 to 19) of std_logic_vector(19 downto 0);
    constant PLAYER_MASK : t_mask_20x20 := (
    0  => "00000000011110000000",
    1  => "00000111111111110000",
    2  => "00000000111111000000",
    3  => "00000011111111100000",
    4  => "00000011111111100000",
    5  => "00000001111111000000",
    6  => "00000000011100011110",
    7  => "00000000111110010000",
    8  => "00000111111111110000",
    9  => "00001100011100000000",
    10 => "00001000011100000000",
    11 => "00000000011100000000", -- แขนยกถือปืนขวา
    12 => "00000000011100000000",
    13 => "00000000011100000000",
    14 => "00000000011100000000",
    15 => "00000000111110000000",
    16 => "00000001100011000000",
    17 => "00000011000001100000",
    18 => "00000110000000110000",
    19 => "00000000000000000000"
);
    -- --------------------------------------------------------------------
    -- Text/Sprite Rendering Functions
    -- --------------------------------------------------------------------
    function get_char_pixel (constant c : character; constant px : integer; constant py : integer) return std_logic is
        type t_font_8x8 is array (0 to 7) of std_logic_vector(7 downto 0); variable font_map : t_font_8x8; variable font_data : std_logic_vector(7 downto 0);
    begin
        case c is
            when 'G' => font_map := (0=>"01111110", 1=>"10000001", 2=>"10000000", 3=>"10000000", 4=>"10001110", 5=>"10000010", 6=>"10000001", 7=>"01111110");
            when 'A' => font_map := (0=>"00011000", 1=>"00100100", 2=>"01000010", 3=>"11111111", 4=>"10000001", 5=>"10000001", 6=>"10000001", 7=>"00000000");
            when 'M' => font_map := (0=>"10000001", 1=>"11000011", 2=>"10100101", 3=>"10011001", 4=>"10000001", 5=>"10000001", 6=>"10000001", 7=>"10000001");
            when 'E' => font_map := (0=>"11111111", 1=>"10000000", 2=>"10000000", 3=>"11111000", 4=>"10000000", 5=>"10000000", 6=>"10000000", 7=>"11111111");
            when 'O' => font_map := (0=>"01111110", 1=>"10000001", 2=>"10000001", 3=>"10000001", 4=>"10000001", 5=>"10000001", 6=>"10000001", 7=>"01111110");
            when 'V' => font_map := (0=>"10000001", 1=>"10000001", 2=>"10000001", 3=>"10000001", 4=>"01000010", 5=>"01000010", 6=>"00100100", 7=>"00011000");
            when 'R' => font_map := (0=>"11111110", 1=>"10000001", 2=>"10000001", 3=>"11111110", 4=>"10001000", 5=>"10000100", 6=>"10000010", 7=>"10000001");
            when 'P' => font_map := (0=>"11111110", 1=>"10000001", 2=>"10000001", 3=>"11111110", 4=>"10000000", 5=>"10000000", 6=>"10000000", 7=>"10000000");
            when '1' => font_map := (0=>"00100000", 1=>"01100000", 2=>"00100000", 3=>"00100000", 4=>"00100000", 5=>"00100000", 6=>"00100000", 7=>"01110000");
            when '2' => font_map := (0=>"01111100", 1=>"10000010", 2=>"00000100", 3=>"00001000", 4=>"00010000", 5=>"00100000", 6=>"01000000", 7=>"11111111");
            when 'W' => font_map := (0=>"10000001", 1=>"10000001", 2=>"10000001", 3=>"10010001", 4=>"10010001", 5=>"10101001", 6=>"10101001", 7=>"01000110");
            when 'I' => font_map := (0=>"11111111", 1=>"00010000", 2=>"00010000", 3=>"00010000", 4=>"00010000", 5=>"00010000", 6=>"00010000", 7=>"11111111");
            when 'N' => font_map := (0=>"10000001", 1=>"11000001", 2=>"10100001", 3=>"10010001", 4=>"10001001", 5=>"10000101", 6=>"10000011", 7=>"10000001");
            when 'S' => font_map := (0=>"01111110", 1=>"10000000", 2=>"10000000", 3=>"01111110", 4=>"00000001", 5=>"00000001", 6=>"10000001", 7=>"01111110");
            when 'H' => font_map := (0=>"10000001", 1=>"10000001", 2=>"10000001", 3=>"11111111", 4=>"10000001", 5=>"10000001", 6=>"10000001", 7=>"10000001");
            when ' ' => font_map := (others => "00000000");
            when others => font_map := (others => "00000000");
        end case;
        
        font_data := font_map(py); return font_data(7 - px); 
    end function get_char_pixel;
    
    -- Function to get the Player Sprite mask pixel (Modified to accept facing)
    function get_player_mask (
        constant px : integer; 
        constant py : integer;
        constant facing : integer -- 0:Up, 1:Down, 2:Left, 3:Right
    ) return std_logic is
        variable mask_data : std_logic_vector(19 downto 0);
        variable mapped_px : integer := px;
    begin
        
        -- Horizontal Mirroring if facing Left (2)
        if facing = 2 then
            mapped_px := PLAYER_SPRITE_WIDTH - 1 - px;
        end if;
        
        if py < 0 or py >= PLAYER_SPRITE_HEIGHT or mapped_px < 0 or mapped_px >= PLAYER_SPRITE_WIDTH then return '0'; end if;
        
        mask_data := PLAYER_MASK(py); return mask_data(PLAYER_SPRITE_WIDTH - 1 - mapped_px);
    end function get_player_mask;

    -- Function to get the Bullet Sprite mask pixel
    function get_bullet_mask (constant px : integer; constant py : integer) return std_logic is
        variable mask_data : std_logic_vector(3 downto 0);
    begin
        if py < 0 or py >= BULLET_SPRITE_HEIGHT or px < 0 or px >= BULLET_SPRITE_WIDTH then return '0'; end if;
        mask_data := FIREBALL_MASK(py); return mask_data(BULLET_SPRITE_WIDTH - 1 - px);
    end function get_bullet_mask;


begin
    
    -- Connect internal hit/game over signals to output pins
    hit_p1_out <= s_hit_p1; hit_p2_out <= s_hit_p2;
    game_over_p1_out <= s_game_over_p1; game_over_p2_out <= s_game_over_p2;

    ----------------------------------------------------------------------
    -- VGA Sync Generation
    ----------------------------------------------------------------------
    process(clk25)
    begin
        if rising_edge(clk25) then
            if h_count = 799 then
                h_count <= 0;
                if v_count = 524 then v_count <= 0; else v_count <= v_count + 1; end if;
            else h_count <= h_count + 1; end if;
        end if;
    end process;

    -- HSYNC: ใช้ค่าที่เลื่อนภาพไปขวา (664 ถึง 760)
    hsync <= '0' when (h_count>=664 and h_count<760) else '1';
    vsync <= '0' when (v_count>=490 and v_count<492) else '1';
    h_active <= '1' when (h_count<640) else '0';
    v_active <= '1' when (v_count<480) else '0';

    ----------------------------------------------------------------------
    -- Input Decoding
    ----------------------------------------------------------------------
    btn_up<=data_in(0);  btn_down<=data_in(1);  btn_left<=data_in(2);
    btn_right<=data_in(3); btn_fire<=data_in(4); ready_flag<=data_in(7);

    btn2_up<=data_in2(0); btn2_down<=data_in2(1); btn2_left<=data_in2(2);
    btn2_right<=data_in2(3); btn2_fire<=data_in2(4); ready2_flag<=data_in2(7);

    ----------------------------------------------------------------------
    -- Game Logic
    ----------------------------------------------------------------------
    process(clk25)
    begin
        if rising_edge(clk25) then
            
            -- RESET RAW HIT SIGNALS (1 cycle)
            s_raw_hit_p1 <= '0'; s_raw_hit_p2 <= '0';
            
            -- PULSE STRETCHING LOGIC (สร้าง 3-Cycle Pulse)
            hit_delay2_p1 <= hit_delay1_p1; hit_delay1_p1 <= s_raw_hit_p1;
            hit_delay2_p2 <= hit_delay1_p2; hit_delay1_p2 <= s_raw_hit_p2;
            s_hit_p1 <= s_raw_hit_p1 or hit_delay1_p1 or hit_delay2_p1;
            s_hit_p2 <= s_raw_hit_p2 or hit_delay1_p2 or hit_delay2_p2;

            -- Game State Transition Check (Game Over Condition)
            if game_state = STATE_PLAYING then
                if hp1 = 0 or hp2 = 0 then 
                    game_state <= STATE_GAME_OVER;
                    if hp1 = 0 then winner_p2 <= '1'; else winner_p1 <= '1'; end if;
                    s_game_over_p1 <= '1'; s_game_over_p2 <= '1'; -- Send Game Over signal to BOTH
                end if;
            end if;

            case game_state is
                when STATE_PLAYING =>
                    fire_buttons_released <= '0'; 

                    if move_div = 200000 then move_div <= 0;

                        -- Player movement 
                        if ready_flag='1' then
                            if btn_up='1' and y1_pos > 0 then y1_pos <= y1_pos-1; facing1 <= 0; elsif btn_down='1' and y1_pos < MAX_Y_POS then y1_pos <= y1_pos+1; facing1 <= 1; end if;
                            if btn_left='1' and x1_pos > 0 then x1_pos <= x1_pos-1; facing1 <= 2; elsif btn_right='1' and x1_pos < MAX_X_POS then x1_pos <= x1_pos+1; facing1 <= 3; end if; 
                        end if;
                        
                        if ready2_flag='1' then
                            if btn2_up='1' and y2_pos > 0 then y2_pos <= y2_pos-1; facing2 <= 0; elsif btn2_down='1' and y2_pos < MAX_Y_POS then y2_pos <= y2_pos+1; facing2 <= 1; end if;
                            if btn2_left='1' and x2_pos > 0 then x2_pos <= x2_pos-1; facing2 <= 2; elsif btn2_right='1' and x2_pos < MAX_X_POS then x2_pos <= x2_pos+1; facing2 <= 3; end if;
                        end if;

                        -- Bullet logic and Hit Detection
                        for i in 0 to 7 loop
                            if bullets1(i).active='1' then
                                case bullets1(i).dir is
                                    when 0 => bullets1(i).y <= bullets1(i).y-6; when 1 => bullets1(i).y <= bullets1(i).y+6; 
                                    when 2 => bullets1(i).x <= bullets1(i).x-6; when 3 => bullets1(i).x <= bullets1(i).x+6; when others=>null; end case;
                                if bullets1(i).x < 0 or bullets1(i).x > 639 or bullets1(i).y < 0 or bullets1(i).y > 479 then bullets1(i).active <= '0';
                                elsif (bullets1(i).x >= x2_pos and bullets1(i).x < x2_pos + PLAYER_SIZE) and (bullets1(i).y >= y2_pos and bullets1(i).y < y2_pos + PLAYER_SIZE) then
                                    bullets1(i).active <= '0';
                                    if hp2 > 10 then hp2 <= hp2 - 10; else hp2 <= 0; end if; s_raw_hit_p2 <= '1'; end if;
                            end if;
                            if bullets2(i).active='1' then
                                case bullets2(i).dir is
                                    when 0 => bullets2(i).y <= bullets2(i).y-6; when 1 => bullets2(i).y <= bullets2(i).y+6; 
                                    when 2 => bullets2(i).x <= bullets2(i).x-6; when 3 => bullets2(i).x <= bullets2(i).x+6; when others=>null; end case;
                                if bullets2(i).x < 0 or bullets2(i).x > 639 or bullets2(i).y < 0 or bullets2(i).y > 479 then bullets2(i).active <= '0';
                                elsif (bullets2(i).x >= x1_pos and bullets2(i).x < x1_pos + PLAYER_SIZE) and (bullets2(i).y >= y1_pos and bullets2(i).y < y1_pos + PLAYER_SIZE) then
                                    bullets2(i).active <= '0';
                                    if hp1 > 10 then hp1 <= hp1 - 10; else hp1 <= 0; end if; s_raw_hit_p1 <= '1'; end if;
                            end if;
                        end loop;

                        if fire_cooldown1 > 0 then fire_cooldown1 <= fire_cooldown1 - 1; end if; if fire_cooldown2 > 0 then fire_cooldown2 <= fire_cooldown2 - 1; end if;
                        if btn_fire='1' and fire_cooldown1=0 then
                            bullets1(bullet_index1).active <= '1'; bullets1(bullet_index1).x <= x1_pos + PLAYER_SIZE/2; bullets1(bullet_index1).y <= y1_pos + PLAYER_SIZE/2; bullets1(bullet_index1).dir <= facing1;
                            bullet_index1 <= (bullet_index1 + 1) mod 8; fire_cooldown1 <= FIRE_COOLDOWN_MAX; end if;
                        if btn2_fire='1' and fire_cooldown2=0 then
                            bullets2(bullet_index2).active <= '1'; bullets2(bullet_index2).x <= x2_pos + PLAYER_SIZE/2; bullets2(bullet_index2).y <= y2_pos + PLAYER_SIZE/2; bullets2(bullet_index2).dir <= facing2;
                            bullet_index2 <= (bullet_index2 + 1) mod 8; fire_cooldown2 <= FIRE_COOLDOWN_MAX; end if;

                    else move_div <= move_div + 1; end if;
                    
                when STATE_GAME_OVER =>
                    if btn_fire='0' and btn2_fire='0' then fire_buttons_released <= '1'; end if;
                    if fire_buttons_released='1' and btn_fire='1' and btn2_fire='1' then
                        game_state <= STATE_PLAYING; hp1 <= MAX_HP; hp2 <= MAX_HP;
                        winner_p1 <= '0'; winner_p2 <= '0'; s_game_over_p1 <= '0'; s_game_over_p2 <= '0';
                        x1_pos <= 200; y1_pos <= 200; x2_pos <= 420; y2_pos <= 420;
                        bullets1 <= (others => (x=>-16, y=>0, active=>'0', dir=>0)); bullets2 <= (others => (x=>-16, y=>0, active=>'0', dir=>0));
                        fire_cooldown1 <= 0; fire_cooldown2 <= 0; bullet_index1 <= 0; bullet_index2 <= 0;
                    end if;
            end case;
        end if;
    end process;

    ----------------------------------------------------------------------
    -- VGA Draw Logic (Players, Bullets, HP Bar, and Game Over Screen)
    ----------------------------------------------------------------c  	`qqqqqqqqqqqqqqqqq------
    process(clk25)
        variable bar_len1, bar_len2 : integer; variable current_color : std_logic_vector(2 downto 0);
        variable char_x, char_y : integer; variable char_pixel : std_logic;
        variable player1_sprite_px, player1_sprite_py : integer; variable player2_sprite_px, player2_sprite_py : integer;
        variable bullet1_sprite_px, bullet1_sprite_py : integer; variable bullet2_sprite_px, bullet2_sprite_py : integer;
        constant GRID_SIZE : integer := 16; constant LINE_THICKNESS : integer := 1;
        variable h_mod : integer; variable v_mod : integer;
        
    begin
        if rising_edge(clk25) then current_color := C_BLACK; 

            if h_active='1' and v_active='1' then

                if game_state = STATE_PLAYING then
                    h_mod := h_count mod GRID_SIZE; v_mod := v_count mod GRID_SIZE;
                    current_color := C_BLACK; 
                    if (h_mod < LINE_THICKNESS) or (v_mod < LINE_THICKNESS) then current_color := C_DARK_GRAY; end if;

                    player1_sprite_px := h_count - x1_pos; player1_sprite_py := v_count - y1_pos;
                    if player1_sprite_px >= 0 and player1_sprite_px < PLAYER_SPRITE_WIDTH and player1_sprite_py >= 0 and player1_sprite_py < PLAYER_SPRITE_HEIGHT then
                        if get_player_mask(player1_sprite_px, player1_sprite_py, facing1) = '1' then current_color := C_YELLOW; end if; end if; -- PASS FACING1

                    player2_sprite_px := h_count - x2_pos; player2_sprite_py := v_count - y2_pos;
                    if player2_sprite_px >= 0 and player2_sprite_px < PLAYER_SPRITE_WIDTH and player2_sprite_py >= 0 and player2_sprite_py < PLAYER_SPRITE_HEIGHT then
                        if get_player_mask(player2_sprite_px, player2_sprite_py, facing2) = '1' then current_color := C_CYAN; end if; end if; -- PASS FACING2
                    
                    for i in 0 to 7 loop
                        if bullets1(i).active='1' then
                            bullet1_sprite_px := h_count - bullets1(i).x; bullet1_sprite_py := v_count - bullets1(i).y;
                            if bullet1_sprite_px >= 0 and bullet1_sprite_px < BULLET_SPRITE_WIDTH and bullet1_sprite_py >= 0 and bullet1_sprite_py < BULLET_SPRITE_HEIGHT then
                                if get_bullet_mask(bullet1_sprite_px, bullet1_sprite_py) = '1' then current_color := C_RED; end if; end if; end if;
                        if bullets2(i).active='1' then
                            bullet2_sprite_px := h_count - bullets2(i).x; bullet2_sprite_py := v_count - bullets2(i).y;
                            if bullet2_sprite_px >= 0 and bullet2_sprite_px < BULLET_SPRITE_WIDTH and bullet2_sprite_py >= 0 and bullet2_sprite_py < BULLET_SPRITE_HEIGHT then
                                if get_bullet_mask(bullet2_sprite_px, bullet2_sprite_py) = '1' then current_color := C_GREEN; end if; end if; end if;
                    end loop;
                    
                    bar_len1 := hp1 * 2; bar_len2 := hp2 * 2;
                    if v_count >= HP_BAR_Y_START and v_count <= HP_BAR_Y_END then
                        if (h_count >= P1_BAR_LEFT_X and h_count <= P1_BAR_RIGHT_X) and (v_count = HP_BAR_Y_START or v_count = HP_BAR_Y_END or h_count = P1_BAR_LEFT_X or h_count = P1_BAR_RIGHT_X) then current_color := C_WHITE;
                        elsif h_count > P1_BAR_LEFT_X and h_count < P1_BAR_LEFT_X + bar_len1 + 1 and v_count > HP_BAR_Y_START and v_count < HP_BAR_Y_END then
                            if hp1 > 60 then current_color := C_GREEN; elsif hp1 > 30 then current_color := C_YELLOW; else current_color := C_RED; end if; end if;
                        
                        if (h_count >= P2_BAR_LEFT_X and h_count <= P2_BAR_RIGHT_X) and (v_count = HP_BAR_Y_START or v_count = HP_BAR_Y_END or h_count = P2_BAR_LEFT_X or h_count = P2_BAR_RIGHT_X) then current_color := C_WHITE;
                        elsif h_count > P2_BAR_LEFT_X and h_count < P2_BAR_LEFT_X + bar_len2 + 1 and v_count > HP_BAR_Y_START and v_count < HP_BAR_Y_END then
                            if hp2 > 60 then current_color := C_GREEN; elsif hp2 > 30 then current_color := C_YELLOW; else current_color := C_RED; end if; end if;
                    end if;

                    for char_idx in 0 to 1 loop 
                        char_x := h_count - (HP1_TEXT_START_X + char_idx * (CHAR_WIDTH + CHAR_SPACING)); char_y := v_count - HP1_TEXT_START_Y;
                        if char_x >= 0 and char_x < CHAR_WIDTH and char_y >= 0 and char_y < CHAR_HEIGHT then case char_idx is when 0 => char_pixel := get_char_pixel('H', char_x, char_y); when 1 => char_pixel := get_char_pixel('P', char_x, char_y); when others => char_pixel := '0'; end case;
                            if char_pixel = '1' then current_color := C_WHITE; end if; end if; end loop;

                    for char_idx in 0 to 1 loop 
                        char_x := h_count - (P1_NAME_TEXT_START_X + char_idx * (CHAR_WIDTH + CHAR_SPACING)); char_y := v_count - P1_NAME_TEXT_START_Y;
                        if char_x >= 0 and char_x < CHAR_WIDTH and char_y >= 0 and char_y < CHAR_HEIGHT then case char_idx is when 0 => char_pixel := get_char_pixel('P', char_x, char_y); when 1 => char_pixel := get_char_pixel('1', char_x, char_y); when others => char_pixel := '0'; end case;
                            if char_pixel = '1' then current_color := C_YELLOW; end if; end if; end loop;

                    for char_idx in 0 to 1 loop 
                        char_x := h_count - (HP2_TEXT_START_X + char_idx * (CHAR_WIDTH + CHAR_SPACING)); char_y := v_count - HP2_TEXT_START_Y;
                        if char_x >= 0 and char_x < CHAR_WIDTH and char_y >= 0 and char_y < CHAR_HEIGHT then case char_idx is when 0 => char_pixel := get_char_pixel('H', char_x, char_y); when 1 => char_pixel := get_char_pixel('P', char_x, char_y); when others => char_pixel := '0'; end case;
                            if char_pixel = '1' then current_color := C_WHITE; end if; end if; end loop;

                    for char_idx in 0 to 1 loop 
                        char_x := h_count - (P2_NAME_TEXT_START_X + char_idx * (CHAR_WIDTH + CHAR_SPACING)); char_y := v_count - P2_NAME_TEXT_START_Y;
                        if char_x >= 0 and char_x < CHAR_WIDTH and char_y >= 0 and char_y < CHAR_HEIGHT then case char_idx is when 0 => char_pixel := get_char_pixel('P', char_x, char_y); when 1 => char_pixel := get_char_pixel('2', char_x, char_y); when others => char_pixel := '0'; end case;
                            if char_pixel = '1' then current_color := C_CYAN; end if; end if; end loop;

                else -- game_state = STATE_GAME_OVER
                    if winner_p1 = '1' then current_color := C_YELLOW; elsif winner_p2 = '1' then current_color := C_CYAN; else current_color := C_RED; end if;
                    if h_count > 120 and h_count < 520 and v_count > 100 and v_count < 380 then current_color := C_BLACK; end if;
                    
                    for char_idx in 0 to 8 loop
                        char_x := h_count - (GO_START_X + char_idx * (CHAR_WIDTH + CHAR_SPACING)); char_y := v_count - GO_START_Y;
                        if char_x >= 0 and char_x < CHAR_WIDTH and char_y >= 0 and char_y < CHAR_HEIGHT then
                            case char_idx is
                                when 0 => char_pixel := get_char_pixel('G', char_x, char_y); when 1 => char_pixel := get_char_pixel('A', char_x, char_y); when 2 => char_pixel := get_char_pixel('M', char_x, char_y); 
                                when 3 => char_pixel := get_char_pixel('E', char_x, char_y); when 4 => char_pixel := get_char_pixel(' ', char_x, char_y); when 5 => char_pixel := get_char_pixel('O', char_x, char_y);
                                when 6 => char_pixel := get_char_pixel('V', char_x, char_y); when 7 => char_pixel := get_char_pixel('E', char_x, char_y); when 8 => char_pixel := get_char_pixel('R', char_x, char_y); when others => char_pixel := '0'; end case;
                            if char_pixel = '1' then current_color := C_WHITE; end if; end if; end loop;
                    
                    for char_idx in 0 to 6 loop
                        char_x := h_count - (W_START_X + char_idx * (CHAR_WIDTH + CHAR_SPACING)); char_y := v_count - W_START_Y;
                        if char_x >= 0 and char_x < CHAR_WIDTH and char_y >= 0 and char_y < CHAR_HEIGHT then
                            char_pixel := '0';
                            if winner_p1 = '1' then
                                case char_idx is when 0 => char_pixel := get_char_pixel('P', char_x, char_y); when 1 => char_pixel := get_char_pixel('1', char_x, char_y); when 2 => char_pixel := get_char_pixel(' ', char_x, char_y);
                                when 3 => char_pixel := get_char_pixel('W', char_x, char_y); when 4 => char_pixel := get_char_pixel('I', char_x, char_y); when 5 => char_pixel := get_char_pixel('N', char_x, char_y);
                                when 6 => char_pixel := get_char_pixel('S', char_x, char_y); when others => char_pixel := '0'; end case;
                                if char_pixel = '1' then current_color := C_YELLOW; end if;
                            elsif winner_p2 = '1' then
                                case char_idx is when 0 => char_pixel := get_char_pixel('P', char_x, char_y); when 1 => char_pixel := get_char_pixel('2', char_x, char_y); when 2 => char_pixel := get_char_pixel(' ', char_x, char_y);
                                when 3 => char_pixel := get_char_pixel('W', char_x, char_y); when 4 => char_pixel := get_char_pixel('I', char_x, char_y); when 5 => char_pixel := get_char_pixel('N', char_x, char_y);
                                when 6 => char_pixel := get_char_pixel('S', char_x, char_y); when others => char_pixel := '0'; end case;
                                if char_pixel = '1' then current_color := C_CYAN; end if; end if; end if;
                    end loop;
                    
                    if h_count < 10 or h_count > 630 or v_count < 10 or v_count > 470 then current_color := C_WHITE; end if;

                end if; end if;
            
            next_vga_r <= current_color(2); next_vga_g <= current_color(1); next_vga_b <= current_color(0);

        end if;
    end process;

    vga_r <= next_vga_r; vga_g <= next_vga_g; vga_b <= next_vga_b;

end Behavioral;