--------------------------------------------------------------------------------
-- File        : tb_perimeter.vhd
-- Description : Behavioural test for the zig-zag ping-pong snake.
--
--   Re-instantiates the structural design with sim-friendly generics and the
--   SAME 33-step forward table as the top, then walks pos = 0..NUM_POS-1
--   forward and reverse, verifying the (digit, segment) pair at each step.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.seg_mux_pkg.all;

entity tb_perimeter is
end entity tb_perimeter;

architecture sim of tb_perimeter is

    constant CLK_PERIOD  : time     := 10 ns;

    constant DBC_CYC     : positive := 4;
    constant STEP_CYC    : positive := 400;
    constant REFRESH_CYC : positive := 3;

    constant SEGS_PER_DIGIT : positive := 5;
    constant FORWARD_LEN    : positive := 8 * SEGS_PER_DIGIT;
    constant NUM_POS        : positive := 2 * FORWARD_LEN;

    constant SEG_OFF : std_logic_vector(6 downto 0) := "1111111";
    constant SEG_B   : std_logic_vector(6 downto 0) := "1011111";
    constant SEG_C   : std_logic_vector(6 downto 0) := "1101111";
    constant SEG_D   : std_logic_vector(6 downto 0) := "1110111";
    constant SEG_E   : std_logic_vector(6 downto 0) := "1111011";
    constant SEG_F   : std_logic_vector(6 downto 0) := "1111101";

    type step_t is record
        digit : integer range 0 to 7;
        seg   : std_logic_vector(6 downto 0);
    end record;

    function fwd_step (idx : integer) return step_t is
        variable r : step_t;
    begin
        r.digit := idx / SEGS_PER_DIGIT;
        case idx mod SEGS_PER_DIGIT is
            when 0      => r.seg := SEG_B;
            when 1      => r.seg := SEG_C;
            when 2      => r.seg := SEG_D;
            when 3      => r.seg := SEG_E;
            when others => r.seg := SEG_F;
        end case;
        return r;
    end function;

    function map_pos (p : integer) return step_t is
    begin
        if p < FORWARD_LEN then return fwd_step(p);
        else                    return fwd_step(NUM_POS - 1 - p);
        end if;
    end function;

    signal clk       : std_logic := '0';
    signal btn_rst_n : std_logic := '0';
    signal sw_dir    : std_logic := '0';
    signal seg_n     : std_logic_vector(6 downto 0);
    signal an_n      : std_logic_vector(7 downto 0);
    signal dp_n      : std_logic;

    signal rst       : std_logic;
    signal sw_dir_db : std_logic;
    signal step_tick : std_logic;
    signal pos       : integer range 0 to NUM_POS-1;
    signal patterns  : seg_array_t;

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

    function count_zeros (v : std_logic_vector) return natural is
        variable n : natural := 0;
    begin
        for i in v'range loop
            if v(i) = '0' then n := n + 1; end if;
        end loop;
        return n;
    end function;

begin

    u_sync_reset : entity work.sync_reset
        port map (clk => clk, async_rstn => btn_rst_n, sync_rst => rst);

    u_debouncer : entity work.debouncer
        generic map (DEBOUNCE_CYCLES => DBC_CYC)
        port map (clk => clk, rst => rst, async_in => sw_dir, clean => sw_dir_db);

    u_step : entity work.tick_gen
        generic map (DIVIDER => STEP_CYC)
        port map (clk => clk, rst => rst, tick => step_tick);

    u_fsm : entity work.snake_fsm
        generic map (NUM_POSITIONS => NUM_POS)
        port map (clk => clk, rst => rst, step => step_tick, dir => sw_dir_db, pos => pos);

    gen_patterns : for d in 0 to 7 generate
        patterns(d) <= map_pos(pos).seg when map_pos(pos).digit = d else SEG_OFF;
    end generate;

    u_mux : entity work.seg_mux
        generic map (REFRESH_DIV => REFRESH_CYC)
        port map (clk => clk, rst => rst, patterns_in => patterns,
                  seg_n => seg_n, an_n => an_n);

    dp_n <= '1';

    clk_proc : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    stim_proc : process

        procedure sample_digit (
            d      : in  integer;
            sample : out std_logic_vector(6 downto 0)
        ) is
        begin
            loop
                wait until rising_edge(clk);
                wait for 1 ns;
                exit when an_n(d) = '0';
            end loop;
            sample := seg_n;
        end procedure;

        variable observed : std_logic_vector(6 downto 0);
        variable expected : step_t;

    begin
        ------------------------------------------------------------------------
        -- Reset
        ------------------------------------------------------------------------
        btn_rst_n <= '0';
        sw_dir    <= '0';
        for i in 0 to 9 loop wait until rising_edge(clk); end loop;
        wait until falling_edge(clk);
        btn_rst_n <= '1';
        for i in 0 to 5 loop wait until rising_edge(clk); end loop;

        ------------------------------------------------------------------------
        -- After reset, pos=0 -> b on digit 0.
        ------------------------------------------------------------------------
        expected := map_pos(0);
        sample_digit(expected.digit, observed);
        check(observed = expected.seg,
              "after reset: digit " & integer'image(expected.digit) &
              " shows expected segment", err_count);

        ------------------------------------------------------------------------
        -- Forward walk: NUM_POS steps. After step s, pos = s mod NUM_POS.
        ------------------------------------------------------------------------
        for s in 1 to NUM_POS loop
            wait until rising_edge(step_tick);
            wait until falling_edge(step_tick);
            wait for CLK_PERIOD;

            expected := map_pos(s mod NUM_POS);
            sample_digit(expected.digit, observed);
            check(observed = expected.seg,
                  "fwd step " & integer'image(s) & ": digit " &
                  integer'image(expected.digit) & " shows expected segment",
                  err_count);
            check(count_zeros(an_n) = 1,
                  "fwd step " & integer'image(s) & ": an_n one-hot-low",
                  err_count);
        end loop;

        ------------------------------------------------------------------------
        -- Reverse walk: flip sw_dir, let it debounce, then NUM_POS steps back.
        ------------------------------------------------------------------------
        sw_dir <= '1';
        for i in 0 to DBC_CYC + 8 loop wait until rising_edge(clk); end loop;

        for s in 1 to NUM_POS loop
            wait until rising_edge(step_tick);
            wait until falling_edge(step_tick);
            wait for CLK_PERIOD;

            -- After s reverse steps from pos=0, pos = (NUM_POS - s) mod NUM_POS.
            expected := map_pos((NUM_POS - s) mod NUM_POS);
            sample_digit(expected.digit, observed);
            check(observed = expected.seg,
                  "rev step " & integer'image(s) & ": digit " &
                  integer'image(expected.digit) & " shows expected segment",
                  err_count);
        end loop;

        ------------------------------------------------------------------------
        -- Mid-op reset returns to pos=0.
        ------------------------------------------------------------------------
        btn_rst_n <= '0';
        for i in 0 to 4 loop wait until rising_edge(clk); end loop;
        wait until falling_edge(clk);
        btn_rst_n <= '1';
        for i in 0 to 5 loop wait until rising_edge(clk); end loop;

        expected := map_pos(0);
        sample_digit(expected.digit, observed);
        check(observed = expected.seg,
              "after mid-op reset: pos=0 segment lit", err_count);

        ------------------------------------------------------------------------
        if err_count = 0 then
            report "==== TB_PERIMETER: ALL CHECKS PASSED ====" severity note;
        else
            report "==== TB_PERIMETER: " & integer'image(err_count) & " FAILURES ====" severity failure;
        end if;

        sim_done <= true;
        wait;
    end process;

end architecture sim;
