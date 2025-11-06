library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_master is
    Port (
        clk      : in  std_logic;                    -- 20 MHz input
        data_in  : in  std_logic_vector(7 downto 0); -- จากบอร์ดลูก 1
        data_in2 : in  std_logic_vector(7 downto 0); -- จากบอร์ดลูก 2
        vga_r    : out std_logic;
        vga_g    : out std_logic;
        vga_b    : out std_logic;
        hsync    : out std_logic;
        vsync    : out std_logic;
        
        -- HIT DETECTION OUTPUTS (ส่งสัญญาณ Hit กลับไปบอร์ดลูก)
        hit_p1_out : out std_logic; 
        hit_p2_out : out std_logic;
        
        -- GAME OVER SYNC OUTPUTS (NEW PINS)
        game_over_p1_out : out std_logic; -- Game Over สำหรับบอร์ดลูก 1 (P133)
        game_over_p2_out : out std_logic  -- Game Over สำหรับบอร์ดลูก 2 (P137)
    );
end top_master;

architecture Structural of top_master is

    -- (Component clk_gen ยังคงเหมือนเดิม)
    component clk_gen
        port (
            clk_in  : in  std_logic;
            clk_out : out std_logic;
            locked  : out std_logic
        );
    end component;

    ----------------------------------------------------------------------
    -- Component: Game Display (VGA + logic) - UPDATED!
    ----------------------------------------------------------------------
    component game_display
        port (
            clk25    : in  std_logic;
            data_in  : in  std_logic_vector(7 downto 0);
            data_in2 : in  std_logic_vector(7 downto 0);
            vga_r    : out std_logic;
            vga_g    : out std_logic;
            vga_b    : out std_logic;
            hsync    : out std_logic;
            vsync    : out std_logic;
            hit_p1_out : out std_logic;
            hit_p2_out : out std_logic;
            game_over_p1_out : out std_logic;
            game_over_p2_out : out std_logic
        );
    end component;

    ----------------------------------------------------------------------
    -- Internal signals
    ----------------------------------------------------------------------
    signal clk25 : std_logic;
    signal locked : std_logic;
    
    -- Internal signals for Hit and Game Over
    signal s_hit_p1 : std_logic;
    signal s_hit_p2 : std_logic;
    signal s_game_over_p1 : std_logic;
    signal s_game_over_p2 : std_logic;

begin
    -- เชื่อมต่อ Internal signals ไปยัง Top-level outputs
    hit_p1_out <= s_hit_p1;
    hit_p2_out <= s_hit_p2;
    game_over_p1_out <= s_game_over_p1;
    game_over_p2_out <= s_game_over_p2;

    ----------------------------------------------------------------------
    -- Instantiate Clock Generator
    ----------------------------------------------------------------------
    u_clk : clk_gen
        port map (
            clk_in  => clk,
            clk_out => clk25,
            locked  => locked
        );

    ----------------------------------------------------------------------
    -- Instantiate VGA Game Display
    ----------------------------------------------------------------------
    u_game : game_display
        port map (
            clk25    => clk25,
            data_in  => data_in,
            data_in2 => data_in2,
            vga_r    => vga_r,
            vga_g    => vga_g,
            vga_b    => vga_b,
            hsync    => hsync,
            vsync    => vsync,
            hit_p1_out => s_hit_p1,
            hit_p2_out => s_hit_p2,
            game_over_p1_out => s_game_over_p1,
            game_over_p2_out => s_game_over_p2
        );

end Structural;