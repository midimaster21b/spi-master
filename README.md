# SPI Master Component

A SPI master component that can be easily integrated in FuseSoC projects. For right now, this repository is being used as a testing ground for some of the BFMs I developed and to help me test the limits of FuseSoC. If you would like the repository that links to my library of FuseSoC components, please [click here](https://github.com/midimaster21b/rtl-core-library).

This core currently only has two parameters:

**Clock Polarity**: The polarity of the clock when the master is not transmitting.

**Clock Phase**: The phase at which data is being transmitted by the master.

## Usage

In order to use this core as it is intended, FuseSoC is required to be installed.

1. Install the python dependencies

  `python install -r requirements.txt`

1. Add my [rtl core library](https://github.com/midimaster21b/rtl-core-library)

  `fusesoc library add --sync-type git --global midi-cores https://github.com/midimaster21b/rtl-core-library.git`


### Simulation

Running the simulation:

`fusesoc --cores-root . run --target sim midimaster21b:comm:spi-master:0.1.1`

Running the simulation with parameters:

`fusesoc --cores-root . run --target sim midimaster21b:comm:spi-master:0.1.1 --CLOCK_POLARITY_G 0 --CLOCK_PHASE_G 1`
