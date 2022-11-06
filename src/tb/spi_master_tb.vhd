----------------------------------------------------------------------------------
-- Company:
-- Engineer: Joshua Edgcombe
--
-- Create Date: 02/16/2019 12:12:54 AM
-- Design Name:
-- Module Name: SPI_master_tb - Behavioral
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

library xil_defaultlib;

entity SPI_master_tb is
end SPI_master_tb;

architecture Behavioral of SPI_master_tb is

  -- Simulation constants
  constant clk_period : time := 10ns;

  -- Block essentials
  signal sim_clk : STD_LOGIC;
  signal sim_rst : STD_LOGIC := '1';

  -- SPI lines
  signal sim_spi_clk : STD_LOGIC;
  signal sim_mosi : STD_LOGIC;
  signal sim_miso : STD_LOGIC := '1';

  -- SPI/Block interface
  signal sim_mosi_byte : STD_LOGIC_VECTOR (7 downto 0) := x"A8";
  signal sim_miso_byte : STD_LOGIC_VECTOR (7 downto 0);
  signal sim_spi_start : STD_LOGIC := '0';
  signal sim_num_rx_bytes : STD_LOGIC_VECTOR (15 downto 0) := x"0004";

  -- DEBUG
  signal curr_state : STD_LOGIC_VECTOR (3 downto 0);
  signal next_state : STD_LOGIC_VECTOR (3 downto 0);

  -- Flags
  signal sim_rx_flag : STD_LOGIC;
  signal sim_spi_busy : STD_LOGIC;

component SPI_Master_State
  Generic (
    Output_Buffer_Size : Integer;
    Input_Buffer_Size : Integer;
    Clock_Polarity : STD_LOGIC;
    Clock_Phase : STD_LOGIC;
    MSB_First : STD_LOGIC
    );
  Port (
    -- Block necessities
    clk : in STD_LOGIC;
    rst : in STD_LOGIC;

    -- SPI lines
    spi_clk : out STD_LOGIC;
    mosi_line : out STD_LOGIC;
    miso_line : in STD_LOGIC;

    -- SPI/Block interface
    mosi_byte : in STD_LOGIC_VECTOR (7 downto 0);
    miso_byte : out STD_LOGIC_VECTOR (7 downto 0);
    start : in STD_LOGIC;
    num_rx_bytes : in STD_LOGIC_VECTOR (15 downto 0);

    -- DEBUG
    curr_state : out STD_LOGIC_VECTOR (3 downto 0);
    nxt_state : out STD_LOGIC_VECTOR (3 downto 0);

    -- Flags
    Rx_Ready_Flag : out STD_LOGIC;
    busy : out STD_LOGIC
    );
end component;


begin
  -- SP1: entity xil_defaultlib.SPI_master
  SP1: SPI_Master_State
    Generic map (
      Output_Buffer_Size => 256,
      Input_Buffer_Size => 1,
      Clock_Polarity => '0',
      Clock_Phase => '0',
      MSB_First => '1'
    )
    Port map (
      -- Block necessities
      clk => sim_clk,
      rst => sim_rst,

      -- SPI lines
      spi_clk => sim_spi_clk,
      mosi_line => sim_mosi,
      miso_line => sim_miso,

      -- SPI/Block interface
      mosi_byte => sim_mosi_byte,
      miso_byte => sim_miso_byte,
      start => sim_spi_start,
      num_rx_bytes => sim_num_rx_bytes,

      -- DEBUG
      curr_state => curr_state,
      nxt_state => next_state,

      -- Flags
      Rx_Ready_Flag => sim_rx_flag,
      busy => sim_spi_busy
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
    wait for 50 ns;
    sim_spi_start <= '1';
    wait for 50 ns;
    sim_spi_start <= '0';

    -- Time align MISO
    wait for 150 ns;

    -- Second byte
    sim_miso <= '0';
    wait for 80 ns;

    -- Third Byte
    sim_miso <= '1';
    wait for 40 ns;
    sim_miso <= '0';
    wait for 40 ns;

    -- Fourth byte
    sim_miso <= '1';
    wait for 20 ns;
    sim_miso <= '0';
    wait for 20 ns;

    sim_miso <= '1';
    wait for 20 ns;
    sim_miso <= '0';
    wait for 20 ns;


    wait;
  end process;

end Behavioral;
