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

    ----------------------------------------------------------------------------
    -- TODO Step 1: 2-FF synchronizer for async_in
    --   signal sync_ff1, sync_ff2 : std_logic;
    ----------------------------------------------------------------------------


    ----------------------------------------------------------------------------
    -- TODO Step 2: Stability counter
    --   signal cnt        : unsigned( ... );  -- wide enough for DEBOUNCE_CYCLES
    --   signal stable_val : std_logic;        -- last accepted value
    ----------------------------------------------------------------------------

begin

    ----------------------------------------------------------------------------
    -- TODO Step 3: Synchronizer process
    --   On every rising_edge(clk):
    --     sync_ff1 <= async_in;
    --     sync_ff2 <= sync_ff1;
    --   On rst, both FFs <= '0'.
    ----------------------------------------------------------------------------


    ----------------------------------------------------------------------------
    -- TODO Step 4: Debounce process
    --   On rst:                cnt <= 0; stable_val <= '0'; (or current input)
    --   On rising_edge(clk):
    --     if sync_ff2 /= stable_val then
    --       cnt <= cnt + 1;
    --       if cnt = DEBOUNCE_CYCLES-1 then
    --         stable_val <= sync_ff2;
    --         cnt        <= 0;
    --       end if;
    --     else
    --       cnt <= 0;
    --     end if;
    ----------------------------------------------------------------------------

    -- TODO: clean <= stable_val;

    clean <= '0';  -- safe default until implemented

end architecture rtl;
