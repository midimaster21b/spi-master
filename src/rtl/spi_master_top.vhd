----------------------------------------------------------------------------------
-- Company:
-- Engineer: Joshua Edgcombe
--
-- Create Date: 02/16/2019 02:57:52 PM
-- Design Name:
-- Module Name: SPI_master_top - Behavioral
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
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity spi_master_top is
  Port (
    -- Block necessities
    clk_in : in  std_logic;
    rst_in : in  std_logic;

    -----------------------------------
    -- SPI interface
    -----------------------------------
    sclk   : out std_logic;
    cs     : out std_logic;
    mosi   : out std_logic;
    miso   : in  std_logic;

    -----------------------------------
    -- AXIS interface
    -----------------------------------
    -- Tx
    s_axis_tdata         : in  std_logic_vector( 7 downto 0);
    s_axis_tvalid        : in  std_logic;
    s_axis_tready        : out std_logic;
    s_axis_tlast         : in  std_logic;

    -- Rx
    m_axis_tdata         : out std_logic_vector( 7 downto 0);
    m_axis_tvalid        : out std_logic;
    m_axis_tready        : in  std_logic;
    m_axis_tlast         : out std_logic
    );
end spi_master_top;


architecture rtl of spi_master_top is
  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------
  signal write_byte       : STD_LOGIC_VECTOR( 7 downto 0);
  signal read_byte        : STD_LOGIC_VECTOR( 7 downto 0);
  signal slave_byte_ready : STD_LOGIC;
  signal mosi_byte_ready  : STD_LOGIC;
  signal num_tx_bytes     : STD_LOGIC_VECTOR(15 downto 0);
  signal num_rx_bytes     : STD_LOGIC_VECTOR(15 downto 0);
  signal spi_busy         : STD_LOGIC;
  signal deb_btn          : STD_LOGIC;


begin

  SP1 : entity work.spi_master(rtl)
    generic map (
      CLOCK_POLARITY_G     => '0',
      CLOCK_PHASE_G        => '0',
      MSB_FIRST_G          => '1',
      RST_LEVEL_G          => '1'
      )
    port map (
      -- Block necessities
      clk_in        => clk_in,
      rst_in        => rst_in,

      -----------------------------------
      -- SPI lines
      -----------------------------------
      sclk     => sclk,
      mosi     => mosi,
      miso     => miso,
      cs       => open,

      -----------------------------------
      -- AXIS interface
      -----------------------------------
      -- Tx
      s_axis_tdata  => write_byte,
      s_axis_tvalid => '0',
      s_axis_tready => open,
      s_axis_tlast  => '0',

      -- Rx
      m_axis_tdata  => read_byte,
      m_axis_tvalid => open,
      m_axis_tready => '1',
      m_axis_tlast  => open,

      -----------------------------------
      -- Control & Stats
      -----------------------------------
      -- Control
      trigger       => deb_btn,

      -- Stats
      num_bytes     => num_rx_bytes,
      busy          => spi_busy
      );

end rtl;
