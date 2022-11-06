----------------------------------------------------------------------------------
-- Company:
-- Engineer: Joshua Edgcombe
--
-- Create Date: 02/15/2019 05:51:10 PM
-- Design Name:
-- Module Name: SPI_Master - Behavioral
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

entity SPI_Master is
  Generic (
    Output_Buffer_Size : Integer := 256;
    Input_Buffer_Size : Integer := 1;
    Clock_Polarity : STD_LOGIC := '1';
    Clock_Phase : STD_LOGIC := '0';
    MSB_First : STD_LOGIC := '1'
    );
  Port (
    -- Block necessities
    clk : in STD_LOGIC;
    rst : in STD_LOGIC;

    -- SPI lines
    spi_clk : out STD_LOGIC;
    mosi_line : out STD_LOGIC := '0';
    miso_line : in STD_LOGIC;

    -- SPI/Block interface
    mosi_byte : in STD_LOGIC_VECTOR (7 downto 0);
    miso_byte : out STD_LOGIC_VECTOR (7 downto 0) := x"00";
    start : in STD_LOGIC;
    num_rx_bytes : in STD_LOGIC_VECTOR (15 downto 0);

    -- Flags
    Rx_Ready_Flag : out STD_LOGIC := '0';
    busy : out STD_LOGIC := '0'
    );
end SPI_Master;

architecture Behavioral of SPI_Master is

  signal byte_counter : STD_LOGIC_VECTOR (15 downto 0) := x"0000";
  -- signal byte_rx_count : STD_LOGIC_VECTOR (15 downto 0) := x"0000";
  signal byte_rx_count : STD_LOGIC_VECTOR (15 downto 0);
  -- signal tx_busy : STD_LOGIC := '0';
  signal tx_busy : STD_LOGIC;
  signal tx_clk_delay : STD_LOGIC := '0';
  signal miso_byte_buffer : STD_LOGIC_VECTOR (7 downto 0) := x"00";
  signal start_trigger : STD_LOGIC := '0';
  signal clear_trigger : STD_LOGIC := '0';

  signal start_trigger_temp : STD_LOGIC_VECTOR (1 downto 0) := "00";

begin

  -- Assign tx_busy signal to busy flag
  -- busy <= tx_busy;
  busy <= tx_clk_delay;

  -- Allow trigger that is shorter than a SPI clock cycle
  start_trigger <= (start_trigger or start) and not clear_trigger;

  -- Trigger the sending of data
  start_transfer : process(clk)
  begin
    -- Trigger check on rising edge of clk
    if clk'event and rising_edge(clk) then

      -- Ensure clear trigger bit not set
      clear_trigger <= '0';

      -- Shift current start trigger into vector
      -- start_trigger_temp <= (start_trigger_temp(0 downto 0) & start_trigger);

      -- If start bit set
      -- if start_trigger = '1' and tx_busy /= '1' then
      -- if start_trigger_temp(1) = '1' then

      if byte_counter = x"0000" then
        if start = '1' then

          -- Initialize a transfer
          tx_busy <= '1';

        -- Store the current expected rx byte count
        byte_rx_count <= num_rx_bytes;

        end if;
        -- -- Store the current expected rx byte count
        -- byte_rx_count <= num_rx_bytes;

        -- -- Clear the start trigger
        -- clear_trigger <= '1';

        -- Clear the byte counter
        -- byte_counter <= x"0000";

        -- else
        --   -- Initialize no transfer
        --   tx_busy <= '0';

        --   -- Clear the byte counter
        --   byte_counter <= x"0000";

        -- end if;

      -- Check for end case
      -- Multiply by 8 for 8 bits per byte
      -- +8 for command byte
      -- -1 for zero indexed
      -- elsif byte_counter >= (byte_rx_count(12 downto 0) & "000") + 8 - 1 then
      -- elsif byte_counter >= x"0028" then
      -- else
      elsif byte_counter >= (byte_rx_count(12 downto 0) & "111") then
        -- if byte_counter >= (byte_rx_count(12 downto 0) & "111") then
        -- if byte_counter >= x"0FFF" then
          -- SPI no longer busy
          tx_busy <= '0';

          -- Ensure clear trigger bit not set
          -- clear_trigger <= '0';

          -- -- Clear the start trigger
          -- clear_trigger <= '1';

          -- -- Clear the byte counter
          -- byte_counter <= x"0000";
        -- elsif
        --   -- -- Initialize no transfer
        --   -- tx_busy <= '1';

        --   -- Increment the byte counter
        --   byte_counter <= byte_counter + 1;

        -- end if;

        -- Initialize tx_busy
        -- if tx_busy /= '1' and tx_busy /= '0' then
        --   tx_busy <= '0';
        -- end if;

      end if;

    end if;
  end process;


  -- Read Rx bits
  read_bits : process(clk)
  begin
    -- Trigger check on rising edge of clk
    if clk'event and rising_edge(clk) then
      -- Get past initial command
      if byte_counter >= 8 then
        miso_byte_buffer <= miso_byte_buffer (6 downto 0) & miso_line;
      end if;

    end if;
  end process;


  -- Rx Ready Flag
  rx_flag : process(clk)
  begin
    -- Trigger check on rising edge of clk
    if clk'event and falling_edge(clk) then
      if byte_counter (2 downto 0) = "000" and byte_counter > 8 then
        Rx_Ready_Flag <= '1';

        -- Set miso output byte
        miso_byte <= miso_byte_buffer;

      else
        Rx_Ready_Flag <= '0';

      end if;
    end if;
  end process;


  -- Byte counter
  counter : process(clk)
  begin

    if tx_busy /= '1' then
      -- Reset the counter
      byte_counter <= x"0000";

    elsif clk'event and rising_edge(clk) then
      -- Increment the counter
      byte_counter <= byte_counter + 1;

    end if;
  end process;

  -- SPI clock output
  spi_clk_gen : process(clk)
  begin
    if tx_busy = '1' then

      -- Delay spi_clk for 1 clock cycle
      -- THIS IS A BIT HACKY, REVISIT THIS!!!
      if tx_clk_delay /= '1' then
        tx_clk_delay <= '1';

      else
        spi_clk <= clk;

      end if;

    else
      tx_clk_delay <= '0';
      spi_clk <= Clock_Polarity;

    end if;
  end process;


  -- Output block
  spi_out : process(clk)
  begin

    if Clock_Polarity = '0' and Clock_Phase = '0' then
      if falling_edge(clk) then
        if byte_counter < 8 then
          if MSB_First /= '1' then
            mosi_line <= mosi_byte(to_integer(unsigned(byte_counter)));

          else
            mosi_line <= mosi_byte(7 - to_integer(unsigned(byte_counter)));

          end if;
        end if;
      end if;

    elsif Clock_Polarity = '0' and Clock_Phase = '1' then
      if rising_edge(clk) then
        if byte_counter < 8 then
          if MSB_First /= '1' then
            mosi_line <= mosi_byte(to_integer(unsigned(byte_counter)));

          else
            mosi_line <= mosi_byte(7 - to_integer(unsigned(byte_counter)));

          end if;
        end if;
      end if;

    elsif Clock_Polarity = '1' and Clock_Phase = '0' then
      if rising_edge(clk) then
        if byte_counter < 8 then
          if MSB_First /= '1' then
            mosi_line <= mosi_byte(to_integer(unsigned(byte_counter)));

          else
            mosi_line <= mosi_byte(7 - to_integer(unsigned(byte_counter)));

          end if;
        end if;
      end if;

    elsif Clock_Polarity = '1' and Clock_Phase = '1' then
      if falling_edge(clk) then
        if byte_counter < 8 then
          if MSB_First /= '1' then
            mosi_line <= mosi_byte(to_integer(unsigned(byte_counter)));

          else
            mosi_line <= mosi_byte(7 - to_integer(unsigned(byte_counter)));

          end if;
        end if;
      end if;

    end if;
  end process;
end Behavioral;
