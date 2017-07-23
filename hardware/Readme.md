# Hardware Directory

Here you'll find the files you will need to reproduce Paperback.  There are two boards:

* *PaperBack_Display* The Display breakout board.  Can take an ESP32 Development Kit and run the display without the Video converter board.
* *PaperBack_Converter* The VGA conversion board.  Takes VGA, captures a frame, puts it in memory, then outputs to the ePaper screen.  _You can't run the ESP32 if you choose to dock board 2!_.  
   * *Note: Untested.  Let me build it in case I break something so I can save you the time - otherwise you're on your own.  Build Board 1 for now.*

## Editing the Files

All files are from KiCad, although Gerbers are a universal format.  I've also included the PDF schematics as well if you'd like to spin a new PCB from scratch.

## License

MIT
