library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- A wrapper file for passing generics through
entity spi_master_wrapper is
  generic (
    CLOCK_POLARITY_G     : integer range 0 to 1 := 1;
    CLOCK_PHASE_G        : integer range 0 to 1 := 0;
    MSB_FIRST_G          : integer range 0 to 1 := 1;
    RST_LEVEL_G          : integer range 0 to 1 := 1
    );
  port (
    -- Block necessities
    clk_in               : in  std_logic;
    rst_in               : in  std_logic;

    -----------------------------------
    -- SPI lines
    -----------------------------------
    sclk                 : out std_logic;
    mosi                 : out std_logic;
    miso                 : in  std_logic;
    cs                   : out std_logic;

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
    m_axis_tlast         : out std_logic;

    -----------------------------------
    -- Control & Stats
    -----------------------------------
    -- Control
    trigger              : in  std_logic;

    -- Stats
    num_bytes            : out std_logic_vector(31 downto 0);
    busy                 : out std_logic
    );
end spi_master_wrapper;

architecture rtl of spi_master_wrapper is

  constant clock_polarity_s : std_logic_vector(0 downto 0) := std_logic_vector(to_unsigned(CLOCK_POLARITY_G, 1));
  constant clock_phase_s    : std_logic_vector(0 downto 0) := std_logic_vector(to_unsigned(CLOCK_PHASE_G, 1));
  constant msb_first_s      : std_logic_vector(0 downto 0) := std_logic_vector(to_unsigned(MSB_FIRST_G, 1));
  constant rst_level_s      : std_logic_vector(0 downto 0) := std_logic_vector(to_unsigned(RST_LEVEL_G, 1));

  constant clock_polarity_c : std_logic := clock_polarity_s(0);
  constant clock_phase_c    : std_logic := clock_phase_s(0);
  constant msb_first_c      : std_logic := msb_first_s(0);
  constant rst_level_c      : std_logic := rst_level_s(0);

begin

  u_wrap: entity work.spi_master(rtl)
    generic map (
      CLOCK_POLARITY_G => clock_polarity_c,
      CLOCK_PHASE_G    => clock_phase_c,
      MSB_FIRST_G      => msb_first_c,
      RST_LEVEL_G      => rst_level_c
      )
  port map (
    -- Block necessities
    clk_in        => clk_in,
    rst_in        => rst_in,

    -----------------------------------
    -- SPI lines
    -----------------------------------
    sclk          => sclk,
    mosi          => mosi,
    miso          => miso,
    cs            => cs,

    -----------------------------------
    -- AXIS interface
    -----------------------------------
    -- Tx
    s_axis_tdata  => s_axis_tdata,
    s_axis_tvalid => s_axis_tvalid,
    s_axis_tready => s_axis_tready,
    s_axis_tlast  => s_axis_tlast,

    -- Rx
    m_axis_tdata  => m_axis_tdata,
    m_axis_tvalid => m_axis_tvalid,
    m_axis_tready => m_axis_tready,
    m_axis_tlast  => m_axis_tlast,

    -----------------------------------
    -- Control & Stats
    -----------------------------------
    -- Control
    trigger       => trigger,

    -- Stats
    num_bytes     => num_bytes,
    busy          => busy
    );



end architecture;
