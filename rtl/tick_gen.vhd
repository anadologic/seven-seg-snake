--------------------------------------------------------------------------------
-- File        : tick_gen.vhd
-- Description : Generic clock-divider that emits a one-clock-wide pulse
--               ("tick") every DIVIDER input clock cycles.
--
-- Generics:
--   DIVIDER : number of clk cycles between ticks.
--             e.g. for a 4 Hz tick from 100 MHz: DIVIDER = 25_000_000.
--             e.g. for an 8 kHz refresh from 100 MHz: DIVIDER = 12_500.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tick_gen is
    generic (
        DIVIDER : positive := 25_000_000
    );
    port (
        clk  : in  std_logic;
        rst  : in  std_logic;   -- active-high, synchronous
        tick : out std_logic    -- 1-cycle pulse every DIVIDER clocks
    );
end entity tick_gen;

architecture rtl of tick_gen is

    ----------------------------------------------------------------------------
    -- TODO Step 1: Counter wide enough to count up to DIVIDER-1.
    --   signal cnt : unsigned(... downto 0);
    --   Hint: width = integer(ceil(log2(real(DIVIDER))))
    ----------------------------------------------------------------------------

begin

    ----------------------------------------------------------------------------
    -- TODO Step 2: Counter process
    --   On rst:                cnt <= 0; tick <= '0';
    --   On rising_edge(clk):
    --     if cnt = DIVIDER-1 then
    --       cnt  <= 0;
    --       tick <= '1';
    --     else
    --       cnt  <= cnt + 1;
    --       tick <= '0';
    --     end if;
    --
    --   Note: drive `tick` from a register (not combinationally) to keep
    --   it glitch-free and exactly one clock wide.
    ----------------------------------------------------------------------------

    tick <= '0';  -- safe default until implemented

end architecture rtl;
