library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity clk_gen is
    Port (
        clk_in  : in  std_logic;
        clk_out : out std_logic;
        locked  : out std_logic
    );
end clk_gen;

architecture Behavioral of clk_gen is
    signal clkfx_int : std_logic;
begin
    DCM_inst : DCM_SP
        generic map (
            CLKFX_MULTIPLY => 5,
            CLKFX_DIVIDE   => 4,      -- 20 × (5/4) = 25 MHz
            CLKIN_PERIOD   => 50.0,
            STARTUP_WAIT   => TRUE
        )
        port map (
            CLKIN  => clk_in,
            CLKFB  => '0',
            RST    => '0',
            CLKFX  => clkfx_int,
            LOCKED => locked,
            PSCLK => '0', PSEN => '0', PSINCDEC => '0',
            STATUS => open,
            CLK0 => open, CLK90 => open, CLK180 => open, CLK270 => open,
            CLK2X => open, CLK2X180 => open, CLKDV => open, CLKFX180 => open
        );
    clk_out <= clkfx_int;
end Behavioral;