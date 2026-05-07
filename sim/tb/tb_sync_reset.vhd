--------------------------------------------------------------------------------
-- File        : tb_sync_reset.vhd
-- Description : Self-checking testbench for sync_reset.
--
--   Checks:
--     1) After power-up (async_rstn held low), sync_rst is '1'.
--     2) Async assertion: pulling async_rstn low immediately drives
--        sync_rst high (regardless of clk).
--     3) Sync deassertion: after async_rstn is released ('1'), sync_rst
--        falls to '0' within ~2 clock cycles (the synchronizer depth).
--     4) Glitch on async_rstn shorter than one clock still asserts reset.
--
--   Reports PASS/FAIL via assert with severity failure on mismatch and
--   severity note on success, then stops the simulation.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_sync_reset is
end entity tb_sync_reset;

architecture sim of tb_sync_reset is

    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz

    signal clk        : std_logic := '0';
    signal async_rstn : std_logic := '0';
    signal sync_rst   : std_logic;

    signal sim_done   : boolean := false;
    signal err_count  : natural := 0;

    procedure check (
        cond : in boolean;
        msg  : in string;
        signal err_count : inout natural
    ) is
    begin
        if not cond then
            err_count <= err_count + 1;
            report "CHECK FAIL: " & msg severity error;
        else
            report "CHECK PASS: " & msg severity note;
        end if;
    end procedure;

begin

    ----------------------------------------------------------------------------
    -- DUT
    ----------------------------------------------------------------------------
    dut : entity work.sync_reset
        port map (
            clk        => clk,
            async_rstn => async_rstn,
            sync_rst   => sync_rst
        );

    ----------------------------------------------------------------------------
    -- Clock generator
    ----------------------------------------------------------------------------
    clk_proc : process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    ----------------------------------------------------------------------------
    -- Stimulus + checks
    ----------------------------------------------------------------------------
    stim_proc : process
    begin
        ------------------------------------------------------------------------
        -- 1) Power-up: async_rstn already '0' since init. sync_rst must be '1'.
        ------------------------------------------------------------------------
        wait for CLK_PERIOD;  -- let initial values settle
        check(sync_rst = '1', "power-up: sync_rst held high while rst asserted", err_count);

        ------------------------------------------------------------------------
        -- 2) Release reset and verify deassertion within ~2 clocks.
        ------------------------------------------------------------------------
        wait until rising_edge(clk);
        async_rstn <= '1';

        -- After 2 rising edges, ff1 has shifted in '0' and ff2 has captured it.
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;  -- after the clock edge propagation
        check(sync_rst = '0', "deassertion: sync_rst low within 2 clocks of release", err_count);

        ------------------------------------------------------------------------
        -- 3) Async assertion: pull rst low between clock edges, expect
        --    sync_rst to go high asynchronously.
        ------------------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 2 ns;        -- mid-period, away from any clock edge
        async_rstn <= '0';
        wait for 1 ns;
        check(sync_rst = '1', "async assertion: sync_rst high without waiting for clk", err_count);

        ------------------------------------------------------------------------
        -- 4) Hold reset, then release; verify deassertion is clean again.
        ------------------------------------------------------------------------
        wait for 5 * CLK_PERIOD;
        check(sync_rst = '1', "hold: sync_rst remains high while rst asserted", err_count);

        wait until rising_edge(clk);
        async_rstn <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        check(sync_rst = '0', "deassertion #2: sync_rst low within 2 clocks", err_count);

        ------------------------------------------------------------------------
        -- 5) Short async glitch: drop rst for less than a clock period and
        --    confirm the synchronizer captured it (sync_rst went high).
        ------------------------------------------------------------------------
        wait for 3 * CLK_PERIOD;
        async_rstn <= '0';
        wait for CLK_PERIOD / 4;
        check(sync_rst = '1', "short glitch: async path drove sync_rst high", err_count);
        async_rstn <= '1';

        -- And it recovers afterwards.
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        check(sync_rst = '0', "recovery: sync_rst low again after glitch", err_count);

        ------------------------------------------------------------------------
        -- Done.
        ------------------------------------------------------------------------
        wait for 2 * CLK_PERIOD;

        if err_count = 0 then
            report "==== TB_SYNC_RESET: ALL CHECKS PASSED ====" severity note;
        else
            report "==== TB_SYNC_RESET: " & integer'image(err_count) & " FAILURES ====" severity failure;
        end if;

        sim_done <= true;
        wait;
    end process;

end architecture sim;
