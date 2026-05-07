--------------------------------------------------------------------------------
-- File        : seg_mux.vhd
-- Description : 8-digit time-multiplexed driver for the Nexys A7 7-segment
--               display. The 7 cathodes (seg_n) are shared between all 8
--               digits; only one anode (an_n) is enabled at a time.
--
--   Refresh strategy:
--     - Cycle the active digit at REFRESH_DIV clock cycles per slot.
--       For 100 MHz clk and 1 kHz/digit (8 kHz overall): REFRESH_DIV = 12_500.
--     - For each slot `i`, drive seg_n with patterns_in(i) and pull only
--       an_n(i) low.
--
-- Generics:
--   REFRESH_DIV : clk cycles per digit slot.
--
-- Ports:
--   patterns_in : 8 x 7-bit array of per-digit cathode patterns (active-low).
--                 patterns_in(0) is the digit selected by an_n(0), etc.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

package seg_mux_pkg is
    type seg_array_t is array (0 to 7) of std_logic_vector(6 downto 0);
end package seg_mux_pkg;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

use work.seg_mux_pkg.all;

entity seg_mux is
    generic (
        REFRESH_DIV : positive := 100_000
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;            -- active-high, synchronous
        patterns_in : in  seg_array_t;
        seg_n       : out std_logic_vector(6 downto 0);
        an_n        : out std_logic_vector(7 downto 0)
    );
end entity seg_mux;

architecture rtl of seg_mux is

    constant CNT_W : positive := positive(integer(ceil(log2(real(REFRESH_DIV)))));
    signal cnt     : unsigned(CNT_W-1 downto 0) := (others => '0');
    signal sel     : unsigned(2 downto 0)       := (others => '0');

begin

    -- Refresh-slot counter + digit selector
    refresh_proc : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                cnt <= (others => '0');
                sel <= (others => '0');
            else
                if cnt = to_unsigned(REFRESH_DIV-1, CNT_W) then
                    cnt <= (others => '0');
                    sel <= sel + 1;     -- 3-bit, wraps 7 -> 0 naturally
                else
                    cnt <= cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- Drive cathodes from the selected digit's pattern
    seg_n <= patterns_in(to_integer(sel));

    -- One-hot-low anode select
    an_proc : process (sel)
    begin
        an_n                       <= (others => '1');
        an_n(to_integer(sel))      <= '0';
    end process;

end architecture rtl;
