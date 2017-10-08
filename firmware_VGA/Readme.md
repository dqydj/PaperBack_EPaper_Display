# MODE 2 - VGA

Remember, there are two ways to use PaperBack - either with only the first board and an ESP32 mounted, or with the VGA board attached. In this directory is the firmware to use the VGA monitor capabilities of PaperBack.

There are two devices you will need to program:
* Lattice MachXO LCMXO1200C FPGA
    * Look in the FPGA directory.
    * Code in there was programmed with Lattice Diamond: http://www.latticesemi.com/latticediamond
    * If you do not want to edit the code, a SVF file is included.
    * JTAG pins are clearly labeled on the bottom of the board, near the SRAM.
    * Power the board externally.
* Atmel ATMega328p
    * Look in the Microcontroller directory.
    * Code in there uses the Arduino IDE.
    * EDID code thanks to Rocky Hill: https://www.youtube.com/watch?v=UpAfaAhPGd4 // https://github.com/qbancoffee/edid_simulator
        * Follow his instructions to edit the I2C Library in Arduino
        * Set both to '128':
        * "BUFFER_LENGTH" in "arduino_install_folder/hardware/arduino/avr/libraries/Wire/src/Wire.h"
        * "TWI_BUFFER_LENGTH" in "arduino_install_folder/hardware/arduino/avr/libraries/Wire/src/utility/twi.h"
    * Install Tod E. Kurt's Soft I2C Master
        * https://github.com/todbot/SoftI2CMaster
    * The ICSP pins are next to the microcontroller - use a 3.3V programmer, or set the switch to 'disconnected' and power the board externally.

All code I wrote (the VHDL + a couple lines of C++) is Licensed MIT. 

Again: If you choose to drive PaperBack with the ESP32, DO NOT ATTACH THE SECOND BOARD. They _are_ modular, but I didn't add any electronics to switch between the two. If the second board is added, the ESP32 is connected to the exact same signal lines and you will short. Leave the ESP32 out of the socket.