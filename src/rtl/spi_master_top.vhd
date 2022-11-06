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

    -- SPI lines
    sclk   : out std_logic;
    cs     : out std_logic;
    mosi   : out std_logic;
    miso   : in  std_logic
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
      OUTPUT_BUFFER_SIZE => 256,
      INPUT_BUFFER_SIZE  => 1,
      CLOCK_POLARITY     => '0',
      CLOCK_PHASE        => '0',
      MSB_FIRST          => '1'
      )
    port map (
      -- Block necessities
      clk           => clk_in,
      rst           => rst_in,

      -- SPI lines
      spi_clk       => sclk,
      mosi_line     => mosi,
      miso_line     => miso,

      -----------------------------------
      -- SPI/Block interface
      -----------------------------------
      -- Tx
      s_axis_tdata  => write_byte,

      -- Rx
      m_axis_tdata  => read_byte,

      -- Control
      start         => deb_btn,

      -- Stats
      num_rx_bytes  => num_rx_bytes,
      num_tx_bytes  => num_tx_bytes,

      -- Flags
      Rx_Ready_Flag => slave_byte_ready,
      tx_ready_flag => mosi_byte_ready,
      busy          => spi_busy
      );

end rtl;
