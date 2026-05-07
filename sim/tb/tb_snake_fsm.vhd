--------------------------------------------------------------------------------
-- File        : tb_snake_fsm.vhd
-- Description : Self-checking testbench for snake_fsm.
--
--   Checks:
--     1) Reset forces pos = 0.
--     2) Forward stepping (dir=0) walks 0,1,2,...,N-1,0.
--     3) Reverse stepping (dir=1) walks N-1,N-2,...,0,N-1.
--     4) Without `step`, pos does not change.
--     5) Direction can change mid-walk.
--     6) Synchronous reset returns pos to 0.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_snake_fsm is
end entity tb_snake_fsm;

architecture sim of tb_snake_fsm is

    constant CLK_PERIOD : time     := 10 ns;
    constant N          : positive := 6;

    signal clk  : std_logic := '0';
    signal rst  : std_logic := '1';
    signal step : std_logic := '0';
    signal dir  : std_logic := '0';
    signal pos  : integer range 0 to N-1;

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

    dut : entity work.snake_fsm
        generic map (
            NUM_POSITIONS => N
        )
        port map (
            clk  => clk,
            rst  => rst,
            step => step,
            dir  => dir,
            pos  => pos
        );

    clk_proc : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    stim_proc : process

        -- Pulse `step` for one clock at the desired direction.
        procedure tick (d : std_logic) is
        begin
            wait until rising_edge(clk);
            dir  <= d;
            step <= '1';
            wait until rising_edge(clk);
            step <= '0';
            wait for 1 ns;
        end procedure;

    begin
        ------------------------------------------------------------------------
        -- Reset
        ------------------------------------------------------------------------
        rst <= '1';
        for i in 0 to 2 loop wait until rising_edge(clk); end loop;
        rst <= '0';
        wait for 1 ns;
        check(pos = 0, "after reset: pos = 0", err_count);

        ------------------------------------------------------------------------
        -- Forward walk: 0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 0
        ------------------------------------------------------------------------
        for i in 1 to N-1 loop
            tick('0');
            check(pos = i, "forward: pos = " & integer'image(i), err_count);
        end loop;

        tick('0');
        check(pos = 0, "forward wrap: " & integer'image(N-1) & " -> 0", err_count);

        ------------------------------------------------------------------------
        -- No-step hold: pos should not change without `step`
        ------------------------------------------------------------------------
        for i in 0 to 4 loop wait until rising_edge(clk); end loop;
        wait for 1 ns;
        check(pos = 0, "idle (no step): pos unchanged", err_count);

        ------------------------------------------------------------------------
        -- Reverse walk: 0 -> 5 -> 4 -> 3 -> 2 -> 1 -> 0
        ------------------------------------------------------------------------
        tick('1');
        check(pos = N-1, "reverse wrap: 0 -> " & integer'image(N-1), err_count);

        for i in N-2 downto 0 loop
            tick('1');
            check(pos = i, "reverse: pos = " & integer'image(i), err_count);
        end loop;

        ------------------------------------------------------------------------
        -- Direction change mid-walk
        ------------------------------------------------------------------------
        tick('0');  -- 0 -> 1
        check(pos = 1, "fwd after rev: pos = 1", err_count);
        tick('0');  -- 1 -> 2
        check(pos = 2, "fwd: pos = 2", err_count);
        tick('1');  -- 2 -> 1
        check(pos = 1, "rev mid-walk: pos = 1", err_count);
        tick('1');  -- 1 -> 0
        check(pos = 0, "rev mid-walk: pos = 0", err_count);

        ------------------------------------------------------------------------
        -- Mid-operation synchronous reset
        ------------------------------------------------------------------------
        tick('0'); tick('0'); tick('0');  -- pos = 3
        check(pos = 3, "pre-reset: pos = 3", err_count);

        wait until rising_edge(clk);
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';
        wait for 1 ns;
        check(pos = 0, "mid-op reset: pos = 0", err_count);

        ------------------------------------------------------------------------
        -- Done
        ------------------------------------------------------------------------
        if err_count = 0 then
            report "==== TB_SNAKE_FSM: ALL CHECKS PASSED ====" severity note;
        else
            report "==== TB_SNAKE_FSM: " & integer'image(err_count) & " FAILURES ====" severity failure;
        end if;

        sim_done <= true;
        wait;
    end process;

end architecture sim;
