--------------------------------------------------------------------------------
-- File        : debouncer.vhd
-- Description : Synchronizer + debouncer for a single asynchronous input
--               (slide switch or push-button). Uses a 2-FF synchronizer
--               followed by a counter that requires the synchronized input
--               to remain stable for DEBOUNCE_CYCLES clock cycles before
--               the output is updated.
--
-- Generics:
--   DEBOUNCE_CYCLES : number of clk cycles the input must be stable.
--                     For a 100 MHz clock, ~1_000_000 ≈ 10 ms.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity debouncer is
    generic (
        DEBOUNCE_CYCLES : positive := 1_000_000
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;        -- active-high, synchronous
        async_in : in  std_logic;
        clean    : out std_logic
    );
end entity debouncer;

architecture rtl of debouncer is

    -- 2-FF synchronizer
    signal sync_ff1 : std_logic := '0';
    signal sync_ff2 : std_logic := '0';

    attribute ASYNC_REG             : string;
    attribute ASYNC_REG of sync_ff1 : signal is "TRUE";
    attribute ASYNC_REG of sync_ff2 : signal is "TRUE";

    -- Stability counter wide enough for DEBOUNCE_CYCLES-1
    constant CNT_W : positive := positive(integer(ceil(log2(real(DEBOUNCE_CYCLES)))));
    signal cnt        : unsigned(CNT_W-1 downto 0) := (others => '0');
    signal stable_val : std_logic := '0';

begin

    -- 2-FF synchronizer
    sync_proc : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sync_ff1 <= '0';
                sync_ff2 <= '0';
            else
                sync_ff1 <= async_in;
                sync_ff2 <= sync_ff1;
            end if;
        end if;
    end process;

    -- Stability counter: only adopt sync_ff2 once it has held for
    -- DEBOUNCE_CYCLES consecutive clocks.
    debounce_proc : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                cnt        <= (others => '0');
                stable_val <= '0';
            else
                if sync_ff2 /= stable_val then
                    if cnt = to_unsigned(DEBOUNCE_CYCLES-1, CNT_W) then
                        stable_val <= sync_ff2;
                        cnt        <= (others => '0');
                    else
                        cnt <= cnt + 1;
                    end if;
                else
                    cnt <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    clean <= stable_val;

end architecture rtl;
