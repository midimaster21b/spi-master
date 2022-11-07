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

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity spi_master_top_tb is
end spi_master_top_tb;

architecture behavioral of spi_master_top_tb is
  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------
  -- Simulation constants
  constant clk_period     : time := 10ns;

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------
  -- Block essentials
  signal sim_clk          : std_logic;
  signal sim_rst          : std_logic := '1';
  signal sim_btn          : std_logic := '0';

  -- SPI lines
  signal sim_spi_clk      : std_logic;
  signal sim_mosi         : std_logic;
  signal sim_miso         : std_logic := '1';
  signal sim_spi_cs       : std_logic;

  -- SPI CSR Lines
  signal trig_s           : std_logic := '0';
  signal num_bytes_s      : std_logic_vector(31 downto 0);
  signal spi_busy_s       : std_logic;

  -- Tx
  signal s_axis_tdata_s   : std_logic_vector( 7 downto 0) := x"A6";
  signal s_axis_tvalid_s  : std_logic := '1';
  signal s_axis_tready_s  : std_logic;
  signal s_axis_tlast_s   : std_logic := '1';

  -- Rx
  signal m_axis_tdata_s   : std_logic_vector( 7 downto 0);
  signal m_axis_tvalid_s  : std_logic;
  signal m_axis_tready_s  : std_logic := '1';
  signal m_axis_tlast_s   : std_logic;

begin
  -- Clock process
  clk_process : process
  begin
    sim_clk <= '0'; wait for clk_period / 2;
    sim_clk <= '1'; wait for clk_period / 2;
  end process;


  stim_proc: process
  begin
    -- Allow system to stabilize
    wait for 100 ns;
    sim_rst <= '0';

    wait for 20 ns;
    trig_s <= '1';

    wait for clk_period;
    trig_s <= '0';

    wait;
  end process;


  -- dut: entity work.spi_master_top(rtl)
  --   Port map (
  --     -- Block necessities
  --     clk_in => sim_clk,
  --     rst_in => sim_rst,

  --     -- SPI lines
  --     sclk   => sim_spi_clk,
  --     cs     => sim_spi_cs,
  --     mosi   => sim_mosi,
  --     miso   => sim_miso
  --     );


  dut: entity work.spi_master(rtl)
    generic map (
      CLOCK_POLARITY_G   => '0',
      CLOCK_PHASE_G      => '0',
      MSB_FIRST_G        => '1',
      RST_LEVEL_G        => '1'
      )
    port map (
      -- Block necessities
      clk_in        => sim_clk,
      rst_in        => sim_rst,

      -----------------------------------
      -- SPI lines
      -----------------------------------
      sclk     => sim_spi_clk,
      mosi     => sim_mosi,
      miso     => sim_miso,
      cs       => sim_spi_cs,

      -----------------------------------
      -- AXIS interface
      -----------------------------------
      -- Tx
      s_axis_tdata  => s_axis_tdata_s,
      s_axis_tvalid => s_axis_tvalid_s,
      s_axis_tready => s_axis_tready_s,
      s_axis_tlast  => s_axis_tlast_s,

      -- Rx
      m_axis_tdata  => m_axis_tdata_s,
      m_axis_tvalid => m_axis_tvalid_s,
      m_axis_tready => m_axis_tready_s,
      m_axis_tlast  => m_axis_tlast_s,

      -----------------------------------
      -- Control & Stats
      -----------------------------------
      -- Control
      trigger       => trig_s,

      -- Stats
      num_bytes     => num_bytes_s,
      busy          => spi_busy_s
      );
end behavioral;
