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

  component SPI_master_top
    Port (
      -- Block necessities
      clk : in STD_LOGIC;
      btn : in STD_LOGIC;

      -- SPI lines
      spi_clk : inout STD_LOGIC; -- FOR DEBUG
      mosi_line : out STD_LOGIC;
      miso_line : in STD_LOGIC;
      spi_cs : out STD_LOGIC;
      spi_hold : out STD_LOGIC := '1'; -- Driven low to pause data input and output
      spi_wp : out STD_LOGIC := '0'; -- Driven low to protect protected memory

      -- DEBUG LINES
      slave_byte_vector : out STD_LOGIC_VECTOR (31 downto 0) := x"0000_0000";
      curr_state : out STD_LOGIC_VECTOR (3 downto 0);
      nxt_state : out STD_LOGIC_VECTOR (3 downto 0);
      tx_ready_flag : out STD_LOGIC;
      debug_command_byte : out STD_LOGIC_VECTOR (7 downto 0);

      -- DEBUG LINES (Not for sim) (SPI SALEAE TESTING)
      -- debug_spi_clk : out STD_LOGIC;
      -- debug_spi_miso : out STD_LOGIC;
      -- debug_spi_cs : out STD_LOGIC;
      -- debug_spi_mosi : out STD_LOGIC;

      -- Dev board output
      -- Seven segment
      seven_seg_segments : out STD_LOGIC_VECTOR (7 downto 0);
      seven_seg_select : out STD_LOGIC_VECTOR (3 downto 0);

      -- On board LED's
      dev_board_leds : out STD_LOGIC_VECTOR (15 downto 0)
      );
  end component;


  -- Simulation constants
  constant clk_period : time := 10ns;

  -- Block essentials
  signal sim_clk : STD_LOGIC;
  signal sim_rst : STD_LOGIC := '1';
  signal sim_btn : STD_LOGIC := '0';

  -- SPI lines
  signal sim_spi_clk : STD_LOGIC;
  signal sim_mosi : STD_LOGIC;
  signal sim_miso : STD_LOGIC := '1';
  signal sim_spi_cs : STD_LOGIC;

  -- Sample Output
  -- signal SAMPLE_MISO : STD_LOGIC_VECTOR (31 downto 0) := x"1234_5678";
  signal SAMPLE_MISO : STD_LOGIC_VECTOR (31 downto 0) := x"1111_1111";
  -- signal SAMPLE_MISO : STD_LOGIC_VECTOR (31 downto 0) := x"AAAA_AAAA";
  signal SAMPLE_VALUES : STD_LOGIC_VECTOR (31 downto 0) := x"0000_0000";
  signal seven_seg_disp : STD_LOGIC_VECTOR (7 downto 0);
  signal seven_seg_select : STD_LOGIC_VECTOR (3 downto 0);

  -- DEBUG
  signal curr_state, next_state : STD_LOGIC_VECTOR (3 downto 0);
  signal tx_ready_flag : STD_LOGIC;
  signal cmd_byte : STD_LOGIC_VECTOR (7 downto 0);

begin
  SP1: SPI_master_top
    Port map (
      -- Block necessities
      clk => sim_clk,
      btn => sim_btn,

      -- SPI lines
      spi_clk => sim_spi_clk,
      mosi_line => sim_mosi,
      miso_line => sim_miso,
      spi_cs => sim_spi_cs,

      -- DEBUG LINES
      slave_byte_vector => SAMPLE_VALUES,
      curr_state => curr_state,
      nxt_state => next_state,
      tx_ready_flag => tx_ready_flag,
      debug_command_byte => cmd_byte,

      -- Dev board output
      -- Seven segment
      seven_seg_segments => seven_seg_disp,
      seven_seg_select => seven_seg_select

      -- On board LED's
      -- dev_board_leds : out STD_LOGIC_VECTOR (15 downto 0)
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
