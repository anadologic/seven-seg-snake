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
use IEEE.MATH_REAL.ALL;

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

    constant CNT_W : positive := positive(integer(ceil(log2(real(DIVIDER)))));
    signal cnt    : unsigned(CNT_W-1 downto 0) := (others => '0');
    signal tick_r : std_logic := '0';

begin

    div_proc : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                cnt    <= (others => '0');
                tick_r <= '0';
            else
                if cnt = to_unsigned(DIVIDER-1, CNT_W) then
                    cnt    <= (others => '0');
                    tick_r <= '1';
                else
                    cnt    <= cnt + 1;
                    tick_r <= '0';
                end if;
            end if;
        end if;
    end process;

    tick <= tick_r;

end architecture rtl;
