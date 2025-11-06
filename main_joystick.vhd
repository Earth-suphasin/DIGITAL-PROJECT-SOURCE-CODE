library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity joystick_K1_LED8 is
    Port (
        clk        : in  std_logic;
        btn_up     : in  std_logic;
        btn_down   : in  std_logic;
        btn_left   : in  std_logic;
        btn_right  : in  std_logic;
        btn_fire   : in  std_logic;
        hit_signal : in  std_logic;               -- สัญญาณ Hit จากบอร์ดแม่
        game_over_signal : in std_logic;         -- สัญญาณ Game Over จากบอร์ดแม่
        led        : out std_logic_vector(7 downto 0);
        K2_out     : out std_logic_vector(7 downto 0);
        seg        : out std_logic_vector(6 downto 0);
        com        : out std_logic_vector(3 downto 0);
        
        buzzer_out : out std_logic 
    );
end joystick_K1_LED8;

architecture Behavioral of joystick_K1_LED8 is
    
    signal data_out : std_logic_vector(7 downto 0);
    constant MAX_HP : integer := 100;
    signal hp_value : integer range 0 to MAX_HP := MAX_HP; 
    
    -- HP Tracking
    signal hp_value_prev : integer range 0 to MAX_HP := MAX_HP;
    signal s_hp_changed : std_logic := '0'; 
    
    -- Hit Processing Control
    signal hit_processed : std_logic := '0'; 
    signal game_over_signal_prev : std_logic := '0'; -- สำหรับตรวจจับ Falling Edge Reset
    
    -- 7-segment
    signal digit    : std_logic_vector(3 downto 0);
    signal count    : integer range 0 to 3 := 0;
    signal clkdiv   : integer range 0 to 20000 := 0;
    
    -- Buzzer Tone Generation (20MHz / 10,000 = 2kHz)
    constant TONE_DIV_MAX : integer := 10000 / 2 - 1; 
    signal tone_div : integer range 0 to TONE_DIV_MAX := 0;
    signal s_buzzer_tone : std_logic := '0';
    
    constant BUZZER_PULSE_MAX : integer := 4000000; -- 0.2 seconds
    signal buzzer_pulse_counter : integer range 0 to BUZZER_PULSE_MAX := 0;
    
begin
    
    -------------------------------------------------------------------
    -- Buzzer Tone Generation (2 kHz Square Wave)
    -------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if tone_div = TONE_DIV_MAX then 
                tone_div <= 0;
                s_buzzer_tone <= not s_buzzer_tone;
            else
                tone_div <= tone_div + 1;
            end if;
        end if;
    end process;
    
    buzzer_out <= s_buzzer_tone when buzzer_pulse_counter > 0 else '0';


    -------------------------------------------------------------------
    -- ส่วนส่งข้อมูลและแสดงบน LED (Existing Logic)
    -------------------------------------------------------------------
    data_out(0) <= not btn_up; data_out(1) <= not btn_down;
    data_out(2) <= not btn_left; data_out(3) <= not btn_right;
    data_out(4) <= not btn_fire; data_out(5) <= '0';
    data_out(6) <= '0'; data_out(7) <= '1';
    led <= data_out; K2_out <= data_out;

    -------------------------------------------------------------------
    -- ส่วน Game Logic (HP Reduction, Reset & Buzzer Control)
    -------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            
            -- 1. Pulse Timer Update
            if buzzer_pulse_counter > 0 then
                buzzer_pulse_counter <= buzzer_pulse_counter - 1;
            end if;
            
            -- 2. ตรวจสอบการเปลี่ยนแปลง HP และเริ่ม Buzzer Pulse
            if hp_value < hp_value_prev then
                s_hp_changed <= '1';
                buzzer_pulse_counter <= BUZZER_PULSE_MAX;
            else
                s_hp_changed <= '0';
            end if;
            
            -- 3. ตรวจจับการเริ่มต้นเกมใหม่ (Falling Edge of Game Over Signal)
            if game_over_signal = '0' and game_over_signal_prev = '1' then
                 hp_value <= MAX_HP; 
            
            -- 4. ตรวจสอบ Game Over (Master HP = 0)
            elsif game_over_signal = '1' then
                hp_value <= 0;
                
            -- 5. ตรวจจับ Hit และลด HP
            elsif hit_signal = '1' and hit_processed = '0' then
                
                if hp_value >= 10 then hp_value <= hp_value - 10; else hp_value <= 0; end if;
                hit_processed <= '1'; 
                
            -- 6. เคลียร์สถานะ
            elsif hit_signal = '0' and hit_processed = '1' then
                hit_processed <= '0';
                
            end if;
            
            -- 7. อัปเดตค่าเก่าสำหรับรอบถัดไป
            hp_value_prev <= hp_value;
            game_over_signal_prev <= game_over_signal;
            
        end if;
    end process;
    
    -------------------------------------------------------------------
    -- ส่วนสแกน 7-segment (Clock Division) (Existing Logic)
    -------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if clkdiv = 20000 then
                clkdiv <= 0;
                if count = 3 then count <= 0; else count <= count + 1; end if;
            else clkdiv <= clkdiv + 1; end if;
        end if;
    end process;

    -- *******************************************************************
    -- Segment and Common Driver (Concurrent Assignment)
    -- *******************************************************************
    
    -- 1. Segment Decoder 
    seg <= "1111110" when digit = "0000" else "0110000" when digit = "0001" else 
           "1101101" when digit = "0010" else "1111001" when digit = "0011" else 
           "0110011" when digit = "0100" else "1011011" when digit = "0101" else 
           "1011111" when digit = "0110" else "1110000" when digit = "0111" else 
           "1111111" when digit = "1000" else "1111011" when digit = "1001" else "0000000";

    -- 2. Common Driver 
    with count select com <=
        "1110" when 0, "1101" when 1, "1011" when 2, "1111" when others; 

    -- 3. Digit Scanner 
    process(count, hp_value)
        variable hund_digit : integer range 0 to 9; 
        variable ten_digit  : integer range 0 to 9;  
        variable unit_digit : integer range 0 to 9;  
    begin
        hund_digit := hp_value / 100; ten_digit := (hp_value mod 100) / 10; unit_digit := hp_value mod 10;
        case count is
            when 0 => digit <= conv_std_logic_vector(unit_digit, 4);
            when 1 => digit <= conv_std_logic_vector(ten_digit, 4);
            when 2 => digit <= conv_std_logic_vector(hund_digit, 4);
            when others => digit <= "0000"; end case;
    end process;
end Behavioral;