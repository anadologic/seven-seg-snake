--------------------------------------------------------------------------------
-- File        : sync_reset.vhd
-- Description : 2-flip-flop reset synchronizer.
--               Takes an asynchronous, active-low reset (e.g. from a push
--               button) and produces a synchronous, active-high reset that
--               is safe to use throughout the design.
--
--   Assertion (async_rstn -> 0) is captured asynchronously so reset takes
--   effect immediately. Deassertion is registered through two flip-flops
--   so the rising edge of sync_rst aligns with clk, preventing
--   recovery/removal timing violations on downstream logic.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity sync_reset is
    port (
        clk        : in  std_logic;
        async_rstn : in  std_logic;  -- active-low, asynchronous
        sync_rst   : out std_logic   -- active-high, synchronous to clk
    );
end entity sync_reset;

architecture rtl of sync_reset is

    signal ff1 : std_logic := '1';
    signal ff2 : std_logic := '1';

    -- Tell the synthesizer these flip-flops form a synchronizer so it
    -- doesn't optimize them or pack them into shift-register primitives.
    attribute ASYNC_REG        : string;
    attribute ASYNC_REG of ff1 : signal is "TRUE";
    attribute ASYNC_REG of ff2 : signal is "TRUE";

begin

    process (clk, async_rstn)
    begin
        if async_rstn = '0' then
            ff1 <= '1';
            ff2 <= '1';
        elsif rising_edge(clk) then
            ff1 <= '0';
            ff2 <= ff1;
        end if;
    end process;

    sync_rst <= ff2;

end architecture rtl;
