--------------------------------------------------------------------------------
-- File        : seg_mux.vhd
-- Description : 8-digit time-multiplexed driver for the Nexys A7 7-segment
--               display. The 7 cathodes (seg_n) are shared between all 8
--               digits; only one anode (an_n) is enabled at a time.
--
--   Refresh strategy:
--     - Cycle the active digit at ~1 kHz/digit (8 kHz overall) so the eye
--       sees all 8 digits as steady.
--     - For each refresh slot `i`, drive seg_n with patterns_in(i) and
--       pull only an_n(i) low.
--
-- Generics:
--   REFRESH_DIV : clk cycles per digit slot.
--                 For 100 MHz clk and 1 kHz/digit: 100_000.
--
-- Ports:
--   patterns_in : 8 x 7-bit array of per-digit cathode patterns (active-low).
--                 patterns_in(0) is the digit selected by an_n(0), etc.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package seg_mux_pkg is
    type seg_array_t is array (0 to 7) of std_logic_vector(6 downto 0);
end package seg_mux_pkg;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.seg_mux_pkg.all;

entity seg_mux is
    generic (
        REFRESH_DIV : positive := 100_000
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;            -- active-high, synchronous
        patterns_in : in  seg_array_t;          -- per-digit cathode patterns
        seg_n       : out std_logic_vector(6 downto 0);
        an_n        : out std_logic_vector(7 downto 0)
    );
end entity seg_mux;

architecture rtl of seg_mux is

    ----------------------------------------------------------------------------
    -- TODO Step 1: Refresh-slot tick
    --   Reuse tick_gen (DIVIDER => REFRESH_DIV) to produce a 1-cycle pulse
    --   each time the active digit should advance. Either instantiate
    --   tick_gen here, or inline a small counter.
    ----------------------------------------------------------------------------

    -- TODO: signal slot_tick : std_logic;


    ----------------------------------------------------------------------------
    -- TODO Step 2: Active-digit index (0..7)
    --   signal sel : unsigned(2 downto 0);
    --   On rst:           sel <= (others => '0');
    --   On slot_tick='1': sel <= sel + 1;  -- wraps naturally at 8
    ----------------------------------------------------------------------------

begin

    ----------------------------------------------------------------------------
    -- TODO Step 3: Drive outputs
    --   seg_n <= patterns_in(to_integer(sel));
    --
    --   Build an_n so that exactly the bit indexed by `sel` is '0' and
    --   all others are '1'. One clean way:
    --
    --     process(sel)
    --     begin
    --       an_n <= (others => '1');
    --       an_n(to_integer(sel)) <= '0';
    --     end process;
    ----------------------------------------------------------------------------

    seg_n <= (others => '1');   -- safe defaults: blank display
    an_n  <= (others => '1');

end architecture rtl;
