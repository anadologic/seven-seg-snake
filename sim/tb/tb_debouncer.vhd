--------------------------------------------------------------------------------
-- File        : tb_debouncer.vhd
-- Description : Self-checking testbench for debouncer.
--
--   Uses a small DEBOUNCE_CYCLES (16) so the test runs quickly. Checks:
--     1) Reset clears clean to '0'.
--     2) A bouncing input that never holds long enough does NOT change clean.
--     3) A clean rising edge held for >= DEBOUNCE_CYCLES propagates to clean.
--     4) After clean = '1', a clean falling edge held for >= DEBOUNCE_CYCLES
--        propagates back to '0'.
--     5) A short low-going glitch shorter than DEBOUNCE_CYCLES does NOT
--        change clean from '1'.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_debouncer is
end entity tb_debouncer;

architecture sim of tb_debouncer is

    constant CLK_PERIOD : time     := 10 ns;
    constant DBC        : positive := 16;  -- short value for fast sim

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal async_in : std_logic := '0';
    signal clean    : std_logic;

    signal sim_done  : boolean := false;
    signal err_count : natural := 0;

    procedure check (
        cond             : in    boolean;
        msg              : in    string;
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

    dut : entity work.debouncer
        generic map (
            DEBOUNCE_CYCLES => DBC
        )
        port map (
            clk      => clk,
            rst      => rst,
            async_in => async_in,
            clean    => clean
        );

    clk_proc : process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    stim_proc : process

        -- Drive async_in with rapid toggles — meant to simulate bouncing.
        procedure bounce (cycles : natural) is
        begin
            for i in 0 to cycles-1 loop
                async_in <= not async_in;
                wait until rising_edge(clk);
            end loop;
        end procedure;

        -- Hold async_in steady for n clk cycles.
        procedure hold_for (val : std_logic; n : natural) is
        begin
            async_in <= val;
            for i in 0 to n-1 loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

    begin
        ------------------------------------------------------------------------
        -- 1) Reset behaviour
        ------------------------------------------------------------------------
        async_in <= '0';
        rst      <= '1';
        wait for 3 * CLK_PERIOD;
        wait until rising_edge(clk);
        rst <= '0';
        wait for 1 ns;
        check(clean = '0', "after reset: clean = 0", err_count);

        ------------------------------------------------------------------------
        -- 2) Bouncing input shorter than DBC must not change clean
        ------------------------------------------------------------------------
        bounce(DBC - 2);   -- toggles every clk, never stable for DBC clocks
        wait for 1 ns;
        check(clean = '0', "bouncing input: clean stays 0", err_count);

        ------------------------------------------------------------------------
        -- 3) Clean rising edge held long enough -> clean = '1'
        --    Need DBC stable cycles AFTER passing through 2-FF sync (2 clks).
        ------------------------------------------------------------------------
        hold_for('1', DBC + 4);
        wait for 1 ns;
        check(clean = '1', "stable high for >= DBC: clean rises to 1", err_count);

        ------------------------------------------------------------------------
        -- 4) Short low glitch (< DBC) must NOT pull clean back to 0
        ------------------------------------------------------------------------
        hold_for('0', DBC / 2);   -- 8 cycles, less than DBC=16
        async_in <= '1';
        wait for 1 ns;
        check(clean = '1', "short low glitch: clean stays 1", err_count);

        -- And after the glitch, clean should remain '1' indefinitely.
        hold_for('1', DBC + 4);
        wait for 1 ns;
        check(clean = '1', "post-glitch hold: clean still 1", err_count);

        ------------------------------------------------------------------------
        -- 5) Clean falling edge held long enough -> clean = '0'
        ------------------------------------------------------------------------
        hold_for('0', DBC + 4);
        wait for 1 ns;
        check(clean = '0', "stable low for >= DBC: clean falls to 0", err_count);

        ------------------------------------------------------------------------
        -- 6) Synchronous reset asserts mid-operation
        ------------------------------------------------------------------------
        hold_for('1', DBC + 4);  -- get clean back to 1
        wait for 1 ns;
        check(clean = '1', "re-arm: clean = 1 before mid-op reset", err_count);

        wait until rising_edge(clk);
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';
        wait for 1 ns;
        check(clean = '0', "mid-op reset: clean cleared to 0", err_count);

        ------------------------------------------------------------------------
        -- Done.
        ------------------------------------------------------------------------
        wait for 5 * CLK_PERIOD;

        if err_count = 0 then
            report "==== TB_DEBOUNCER: ALL CHECKS PASSED ====" severity note;
        else
            report "==== TB_DEBOUNCER: " & integer'image(err_count) & " FAILURES ====" severity failure;
        end if;

        sim_done <= true;
        wait;
    end process;

end architecture sim;
