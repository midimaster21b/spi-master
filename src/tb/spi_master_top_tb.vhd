----------------------------------------------------------------------------------
-- Company:
-- Engineer: Joshua Edgcombe
--
-- Create Date: 02/16/2019 03:33:10 PM
-- Design Name:
-- Module Name: SPI_master_top_tb - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

entity SPI_master_top_tb is
end SPI_master_top_tb;

architecture Behavioral of SPI_master_top_tb is
  -- Simulation constants
  constant clk_period     : time := 10ns;

  -- Block essentials
  signal sim_clk          : STD_LOGIC;
  signal sim_rst          : STD_LOGIC := '1';
  signal sim_btn          : STD_LOGIC := '0';

  -- SPI lines
  signal sim_spi_clk      : STD_LOGIC;
  signal sim_mosi         : STD_LOGIC;
  signal sim_miso         : STD_LOGIC := '1';
  signal sim_spi_cs       : STD_LOGIC;

  -- Sample Output
  signal SAMPLE_MISO      : STD_LOGIC_VECTOR (31 downto 0) := x"1111_1111";
  signal SAMPLE_VALUES    : STD_LOGIC_VECTOR (31 downto 0) := x"0000_0000";
  signal seven_seg_disp   : STD_LOGIC_VECTOR (7 downto 0);
  signal seven_seg_select : STD_LOGIC_VECTOR (3 downto 0);

  -- DEBUG
  signal curr_state, next_state : STD_LOGIC_VECTOR (3 downto 0);
  signal tx_ready_flag : STD_LOGIC;
  signal cmd_byte : STD_LOGIC_VECTOR (7 downto 0);

begin
  SP1: entity work.spi_master_top(rtl)
    Port map (
      -- Block necessities
      clk_in => sim_clk,
      rst_in => sim_rst,

      -- SPI lines
      sclk   => sim_spi_clk,
      cs     => sim_spi_cs,
      mosi   => sim_mosi,
      miso   => sim_miso
      );

  -- Clock process
  clk_process : process
  begin
    sim_clk <= '0'; wait for clk_period / 2;
    sim_clk <= '1'; wait for clk_period / 2;
  end process;

  stim_proc : process
  begin
    -- Allow system to stabilize
    wait for 100 ns;
    sim_rst <= '0';

    -- Tell SPI to transmit
    -- wait for 50 ns;
    -- wait for 1000 ns;
    wait for 200 ns;
    sim_btn <= '1';
    wait for 1000 ns;
    sim_btn <= '0';

    -- Time align MISO
    -- wait for 305 ns; -- My clock divider
    wait for 1045 ns; -- Clk wiz version

    -- Simulate MISO line
    for I in 0 to 31 loop
      sim_miso <= SAMPLE_MISO(31 - I);
      wait for 40 ns;
    end loop;

    wait;
  end process;

end Behavioral;
