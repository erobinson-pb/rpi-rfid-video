# rpi-rfid-video
This is a a video player that scans RFID cards to play videos.
The original idea started when a friend asked for advice on an easy to use replacement DVD player for his father who suffers from Alzheimers.  I suggested building a Raspberry Pi based media player that stores his movies in digital file format (MP4, AVI, MOV, MKV, etc) on USB media and scans RFID cards to determine which movie to play.
We ended up building the Raspberry Pi into a simple clean laser cut MDF box that resembles an inbox.  We based the RFID on the low-cost MRFC522 NFC reader and tags.  We used inexpensive ($0.30) NTAG213 RFID stickers stuck to DVD boxes.  His dad now only has to take the box for his chosen movie and place it in the in tray to begin playing it.  There are no mechanical parts and it's very simple to use.
For more information on the features, see the short video clip here: https://www.youtube.com/watch?v=p4mdKdLZ1KY

Installation of the software components is covered in an MS Word doc [here](https://github.com/peg-leg/rpi-rfid-video/raw/master/docs/Simple%20Raspberry%20Pi%20RFID%20Media%20Player%20Installation.docx "Installation doc")

Use is detailed in an MS Word doc [here](https://github.com/peg-leg/rpi-rfid-video/raw/master/docs/Rpi%20RFID%20Movie%20Player%20Instructions%20for%20Use.docx "How to use doc")

A pinout diagram for the RC522 RFID module can be found [here](https://github.com/peg-leg/rpi-rfid-video/raw/master/docs/RFID-RC522%20Pinout.png "RC522 RFID")

A pinout diagram for the three push-to-make control buttons can be found [here](https://github.com/peg-leg/rpi-rfid-video/raw/master/docs/Push-to-make%20button%20pinout.png "Push-to-make pinout")

The documentation is a work in progress.  It will be updated with plans for the box that houses the Pi and components to build an optional CPU temperature controlled fan ASAP.  There will also be documentation for temporarily enabling SSH access to the unit for remote support (over LAN or WiFi) if required.

This project is released under the MIT license:
Copyright 2019 Edward Robinson
Some components included in this release are copyright their individual developers including:
Adafruit retrogame utility: Copyright (c) 2013 Adafruit Industries.  Written by Phil Burgess for Adafruit Industries, distributed under BSD License.
Components borrowed from scripts originally written by Billy Manashi - [bma-diy](https://github.com/bma-diy/rpi-rfid-video "bma-diy") 

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

