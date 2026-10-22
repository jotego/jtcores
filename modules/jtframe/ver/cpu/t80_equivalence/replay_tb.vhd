library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity replay_tb is
end entity;

architecture sim of replay_tb is
    signal clk      : std_logic := '1';
    signal reset_n  : std_logic := '0';
    signal cen      : std_logic := '1';
    signal wait_n   : std_logic := '1';
    signal int_n    : std_logic := '1';
    signal nmi_n    : std_logic := '1';
    signal busrq_n  : std_logic := '1';
    signal out0     : std_logic := '0';
    signal di       : std_logic_vector(7 downto 0) := (others => '0');
    signal m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n : std_logic;
    signal addr      : std_logic_vector(15 downto 0);
    signal dout      : std_logic_vector(7 downto 0);
begin
    uut: entity work.T80s
        port map (
            RESET_n => reset_n, CLK => clk, CEN => cen, WAIT_n => wait_n,
            INT_n => int_n, NMI_n => nmi_n, BUSRQ_n => busrq_n,
            M1_n => m1_n, MREQ_n => mreq_n, IORQ_n => iorq_n,
            RD_n => rd_n, WR_n => wr_n, RFSH_n => rfsh_n,
            HALT_n => halt_n, BUSAK_n => busak_n, OUT0 => out0,
            A => addr, DI => di, DOUT => dout
        );

    process
        file vectors : text open read_mode is "vectors.bin";
        file outputs : text open write_mode is "outputs.csv";
        variable in_line : line;
        variable out_line : line;
        variable din : std_logic_vector(15 downto 0);
        variable packed : std_logic_vector(31 downto 0);
        variable rownum : natural := 0;
        procedure emit(phase : string) is
        begin
            packed := m1_n & mreq_n & iorq_n & rd_n & wr_n & rfsh_n & halt_n & busak_n & addr & dout;
            write(out_line, rownum);
            write(out_line, string'(","));
            write(out_line, phase);
            write(out_line, string'(","));
            write(out_line, packed);
            writeline(outputs, out_line);
        end procedure;
    begin
        wait for 4 ns;
        clk <= '0';
        while not endfile(vectors) loop
            readline(vectors, in_line);
            read(in_line, din);
            reset_n <= din(7);
            cen     <= din(6);
            wait_n  <= din(5);
            int_n   <= din(4);
            nmi_n   <= din(3);
            busrq_n <= din(2);
            out0    <= din(1);
            di      <= din(15 downto 8);
            wait for 1 ns;
            emit("fall");
            wait for 4 ns;
            clk <= '1';
            wait for 1 ns;
            emit("rise");
            rownum := rownum + 1;
            wait for 4 ns;
            clk <= '0';
        end loop;
        report "REPLAY_DONE rows=" & integer'image(rownum) severity note;
        wait;
    end process;
end architecture;
