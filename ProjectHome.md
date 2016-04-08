This is based off code from the reprap (http://reprap.org/bin/view/Main/WebHome) project, though I've managed to rewrite almost all of the code thus far.

The purpose is to allow a computer to send gcode via a USB cable to an arduino which will interpret the gcode and drive stepper motors using traditional a step/dir interface.  The main advantage of this over a PC is that 1) parallel port interfaces are becoming outdated and 2) the PC requires a real time operating system to ensure accurate pulse rates.  These problems are solved with this approach.

My goal is to build enough intelligence to control a PCB mill, but there is no reason the code can't be expanded for any sort of general-purpose milling control.

The main problem with the code is the lack of program space on the arduino's, however, the release of the mega-arduino should allow significant expansion of supported g-codes.