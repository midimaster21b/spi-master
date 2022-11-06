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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

entity SPI_master_top is
  Port (
    -- Block necessities
    clk : in STD_LOGIC;
    send_btn : in STD_LOGIC;

    -- SPI lines
    -- spi_clk : inout STD_LOGIC; -- FOR DEBUG
    mosi_line : out STD_LOGIC;
    miso_line : in STD_LOGIC;
    spi_cs : out STD_LOGIC;
    spi_hold : out STD_LOGIC := '1'; -- Driven low to pause data input and output
    spi_wp : out STD_LOGIC := '0'; -- Driven low to protect protected memory

    -- DEBUG LINES
    -- slave_byte_vector : out STD_LOGIC_VECTOR (31 downto 0) := x"0000_0000";
    -- curr_state : out STD_LOGIC_VECTOR (3 downto 0);
    -- nxt_state : out STD_LOGIC_VECTOR (3 downto 0);
    -- tx_ready_flag : out STD_LOGIC;
    -- debug_command_byte : out STD_LOGIC_VECTOR (7 downto 0);

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
end SPI_master_top;


architecture Behavioral of SPI_master_top is

  -- Declare a byte array type for storing a lits of bytes
  type byte_array is array (integer range <>) of std_logic_vector (7 downto 0);

  -- function init return byte_array is
  --   -- variable retval : byte_array(0 to 3);

  -- begin
  --   --do something (e.g. read data from a file, perform some initialization calculation, ...)

  --   -- return (others => (others => '0'));
  --   return (others => x"00");
  -- end function init;

  component Debouncer
      Port (clk: in STD_LOGIC; btn_in: in STD_LOGIC; btn_out: out STD_LOGIC := '0');
  end component;


  component spi_clk_wiz
    port (
      spi_clk_out_ce : in STD_LOGIC;
      spi_clk_out : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC;
      clk_in1 : in STD_LOGIC
      );
  end component;

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
      num_tx_bytes : in STD_LOGIC_VECTOR (15 downto 0);

      -- DEBUG
      -- curr_state : out STD_LOGIC_VECTOR (3 downto 0);
      -- nxt_state : out STD_LOGIC_VECTOR (3 downto 0);
      trig : out STD_LOGIC;

      -- Flags
      Rx_Ready_Flag : out STD_LOGIC;
      tx_ready_flag : out STD_LOGIC;
      busy : out STD_LOGIC
      );
  end component;

  component seven_segment_controller
    PORT(
      master_clk : in STD_LOGIC;
      enable : in STD_LOGIC;
      In0, In1, In2, In3 : in STD_LOGIC_VECTOR(3 downto 0);
      SevenSegmentOut : out STD_LOGIC_VECTOR(7 downto 0);
      SevenSegmentSelect : out STD_LOGIC_VECTOR(3 downto 0)
      );
  end component;

  -- Constants
  constant num_tx_bytes_const : integer := 4;

  -- Initialize cmd_bytes
  -- signal cmd_bytes : byte_array (0 to 3) := (others => (others => '0'));
  signal cmd_bytes : byte_array (0 to num_tx_bytes_const - 1) := (
    -- 0 => x"03", -- READ
    0 => x"35", -- RCR
    1 => x"03",
    2 => x"03",
    3 => x"03"
    -- 3 => x"04" -- Wrong...?
    -- 3 => x"05"
    -- others => x"03"
    );
  signal prev_flag : STD_LOGIC := '0';

  signal slave_bytes : STD_LOGIC_VECTOR (31 downto 0) := x"FF00FF00";
  signal spi_clk_div : STD_LOGIC;
  signal rst : STD_LOGIC := '0';
  -- signal command_byte : STD_LOGIC_VECTOR (7 downto 0) := x"9F"; -- RDID
  -- signal command_byte : STD_LOGIC_VECTOR (7 downto 0) := x"03"; -- READ
  signal command_byte : STD_LOGIC_VECTOR (7 downto 0) := x"35"; -- RCR
  signal slave_byte : STD_LOGIC_VECTOR (7 downto 0) := x"00";
  signal slave_byte_ready : STD_LOGIC;
  signal mosi_byte_ready : STD_LOGIC;

  -- signal num_tx_bytes : STD_LOGIC_VECTOR (15 downto 0) := x"0001"; -- RDID
  -- signal num_rx_bytes : STD_LOGIC_VECTOR (15 downto 0) := x"0004"; -- RDID
  -- signal num_tx_bytes : STD_LOGIC_VECTOR (15 downto 0) := x"0004"; -- READ
  signal num_tx_bytes : STD_LOGIC_VECTOR (15 downto 0) := x"0001"; -- RCR
  -- signal num_tx_bytes : STD_LOGIC_VECTOR (15 downto 0) := std_logic_vector(to_unsigned(num_tx_bytes_const, num_tx_bytes'length));
  -- signal num_rx_bytes : STD_LOGIC_VECTOR (15 downto 0) := x"0004"; -- READ
  signal num_rx_bytes : STD_LOGIC_VECTOR (15 downto 0) := x"0001"; -- RCR

  signal spi_busy : STD_LOGIC;
  signal deb_btn : STD_LOGIC;
  signal deb_byte : STD_LOGIC;

  -- SPI CLK WIZ WIRES
  signal spi_clk_enable : STD_LOGIC := '1';
  signal spi_clk_locked : STD_LOGIC := '0';

  signal spi_clk : STD_LOGIC; -- NOT DEBUG (Production)
  signal not_rst : STD_LOGIC;

  -- DEBUG: Used for SPI out @ pmod
  signal temp_spi_mosi : STD_LOGIC;
  signal temp_spi_cs : STD_LOGIC;

  -- Debug
  -- signal curr_state, nxt_state : STD_LOGIC_VECTOR (3 downto 0); -- NOT Debug (Production)
  signal trig : STD_LOGIC;
begin

  not_rst <= not rst;

  STARTUPE2_INST: STARTUPE2
    generic map(
      PROG_USR => "FALSE",
      SIM_CCLK_FREQ => 0.0)
    port map (
      CFGCLK => open,
      CFGMCLK => open,
      EOS => open,
      PREQ => open,
      CLK => '0',
      GSR => '0',
      GTS => '0',
      KEYCLEARB => '0',
      PACK => '0',
      USRCCLKO => spi_clk, -- external (EMCCLK) spi_clk signal from the design which is provide signal to output on CCLK pin

      USRCCLKTS => '0', -- Enable CCLK pin
      -- 1-bit input: User CCLK input

      USRDONEO => '1', -- Drive DONE pin High even though tri-state
      -- 1-bit input: User DONE pin output control

      USRDONETS => '1' -- Maintain tri-state of DONE pin
      -- 1-bit input: User DONE 3-state enable output
      );

  SC1 : spi_clk_wiz
    port map (
      spi_clk_out_ce => spi_clk_enable,
      -- spi_clk_out => spi_clk,
      spi_clk_out => spi_clk_div,
      reset => rst,
      locked => spi_clk_locked,
      clk_in1 => clk
      );

  D1 : Debouncer
    Port map (
      clk => clk,
      -- clk => spi_clk_div,
      btn_in => send_btn,
      btn_out => deb_btn
      );

  -- SP1 : entity xil_defaultlib.SPI_Master
  SP1 : SPI_Master_State
    Generic map (
      Output_Buffer_Size => 256,
      Input_Buffer_Size => 1,
      Clock_Polarity => '0',
      Clock_Phase => '0',
      MSB_First => '1'
      )
    Port map (
      -- Block necessities
      clk => spi_clk_div,
      rst => rst,

      -- SPI lines
      spi_clk => spi_clk,
      mosi_line => temp_spi_mosi,
      miso_line => miso_line,

      -- SPI/Block interface
      mosi_byte => command_byte,
      miso_byte => slave_byte,
      start => deb_btn,
      num_rx_bytes => num_rx_bytes,
      num_tx_bytes => num_tx_bytes,

      -- DEBUG LINES
      -- curr_state => curr_state,
      -- nxt_state => nxt_state,
      trig => trig,

      -- Flags
      Rx_Ready_Flag => slave_byte_ready,
      tx_ready_flag => mosi_byte_ready,
      busy => spi_busy
      );

  -- s7 : entity xil_defaultlib.seven_segment_controller
  s7 : seven_segment_controller
    port map (
      master_clk => clk,
      enable => not_rst, -- THIS NEEDS TO BE CHANGED!!!
      In0 => slave_bytes(31 downto 28),
      In1 => slave_bytes(27 downto 24),
      In2 => slave_bytes(23 downto 20),
      In3 => slave_bytes(19 downto 16),
      SevenSegmentOut => seven_seg_segments,
      SevenSegmentSelect => seven_seg_select
      );

  spi_cs <= spi_busy;
  dev_board_leds <= slave_bytes(15 downto 0);
  mosi_line <= temp_spi_mosi; -- Used for testing spi mosi @ pmod

  -- DEBUG (No sim) (SPI SALEAE TESTING)
  -- debug_spi_cs   <= spi_busy;
  -- debug_spi_clk  <= spi_clk;
  -- debug_spi_mosi <= temp_spi_mosi;
  -- debug_spi_miso <= miso_line;

  -- DEBUG (sim)
  -- tx_ready_flag <= mosi_byte_ready;
  -- debug_command_byte <= command_byte;

  -- Read the bytes from the SPI master
  -- Essentially a flag debouncer...
  read_bytes : process(clk)
  begin

    if clk'event and rising_edge(clk) then
      -- Really quick debounce (deb_byte is prev bit)
      if deb_byte = '0' and slave_byte_ready = '1' then

        -- Shift new byte onto bytes
        slave_bytes <= slave_bytes (23 downto 0) & slave_byte;

      end if;

      -- Replace previous bit with current bit
      deb_byte <= slave_byte_ready;
    end if;

    -- slave_byte_vector <= slave_bytes; -- DEBUG (Not for production!)

  end process;

  -- Determines which cmd_byte to supply
  cmd_counter : process(clk)
    variable cmd_count : integer := 0;
  begin

    if clk'event and clk = '1' then
      -- Track the current tx flag (assigned on next clk')
      prev_flag <= mosi_byte_ready;

      -- if device not selected
      if spi_busy = '1' then
        -- Start count out at 0
        cmd_count := 0;

      -- if rising edge of tx flag
      elsif mosi_byte_ready = '1' and prev_flag = '0' then
        -- if cmd_count < integer(to_unsigned(num_tx_bytes)) - 1 then
        if cmd_count < to_integer(unsigned(num_tx_bytes)) - 1 then
          -- Increment command count
          cmd_count := cmd_count + 1;
        end if;

      end if;

      -- Assign the new command byte
      command_byte <= cmd_bytes(cmd_count);
    end if;
  end process;
end Behavioral;
