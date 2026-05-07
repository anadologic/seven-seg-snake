--------------------------------------------------------------------------------
-- File        : snake_fsm.vhd
-- Description : Snake position tracker.
--
--   On each `step` pulse, advances `pos` by +1 or -1 depending on `dir`,
--   wrapping modulo NUM_POSITIONS.
--
-- Generics:
--   NUM_POSITIONS : size of the loop the snake walks around.
--                   For a single-digit demo: 6 (segments a,b,c,d,e,f).
--                   For an 8-digit perimeter loop: see top module.
--
-- Convention:
--   dir = '0' -> increment (forward)
--   dir = '1' -> decrement (reverse)
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity snake_fsm is
    generic (
        NUM_POSITIONS : positive := 6
    );
    port (
        clk  : in  std_logic;
        rst  : in  std_logic;     -- active-high, synchronous
        step : in  std_logic;     -- 1-cycle pulse, advance one step
        dir  : in  std_logic;     -- direction (debounced)
        pos  : out integer range 0 to NUM_POSITIONS-1
    );
end entity snake_fsm;

architecture rtl of snake_fsm is

    ----------------------------------------------------------------------------
    -- TODO Step 1: Position register
    --   signal pos_r : integer range 0 to NUM_POSITIONS-1;
    ----------------------------------------------------------------------------

begin

    ----------------------------------------------------------------------------
    -- TODO Step 2: Sequential update
    --   On rst:                pos_r <= 0;
    --   On rising_edge(clk):
    --     if step = '1' then
    --       if dir = '0' then
    --         if pos_r = NUM_POSITIONS-1 then pos_r <= 0;
    --         else                            pos_r <= pos_r + 1;
    --         end if;
    --       else
    --         if pos_r = 0 then pos_r <= NUM_POSITIONS-1;
    --         else              pos_r <= pos_r - 1;
    --         end if;
    --       end if;
    --     end if;
    ----------------------------------------------------------------------------

    -- TODO: pos <= pos_r;

    pos <= 0;  -- safe default until implemented

end architecture rtl;
