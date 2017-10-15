#include "SoftI2CMaster.h"
#include <Wire.h>

// Switch locations (all on Analog)
#define SW1 0     // ADC0
#define SW2 6     // ADC6
#define SW3 7     // ADC7
#define SW1_OUT 5  // PD5
#define SW2_OUT 6  // PD6
#define SW3_OUT 7  // PD7

// Write address for VGA Capture Chip
#define ADDR9883  0B01001100 // When Select pin grounded, this is the address
#define SEL_9883 8 // Select Pin

// Commands in order. See datasheet of AD9883 or MST9883 or similar.
#define I2C_REG1    0x01
#define CMD1        0x42        // 01H: 1056 Pixels wide
#define CMD2        0x00        // 02H: 0
#define CMD3        0B01100000  // 03H: VCO/CP (first 5)
#define CMD4        0B00001111  // 04H: Phase Register
#define CMD5        0x10        // 05H: Clamp placement
#define CMD6        0x36        // 06H: Clamp duration
#define CMD7        0x10        // 07H: HOP Register
#define CMD8        0x80        // 08H: REDGAIN
#define CMD9        0x66        // 09H: GRNGAIN, set to .7V
#define CMD10       0x80        // 0AH: BLUGAIN
#define CMD11       0x80        // 0BH: REDOFFSET
#define CMD12       0x80        // 0CH: GRNOFFSET
#define CMD13       0x80        // 0DH: BLUOFFSET

// Contrast with red
#define RED_OFFSET  0x0B        // Red offset register
#define RED_VAL     0x40        // Lower = brighter

// Power on and off utilities
#define POW_REG     0x0F        // 0FH: Power and status register
#define POW_OFF     0B01001000  // Turn power off
#define POW_ON      0B01001010  // Turn power on

// 800x600 @ 60Hz with a made up model name.
 const byte edid[128] =
{ 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x41, 0xd0, 0x21, 0x43, 0xc0, 0x09, 0xe7, 0x00,
  0x20, 0x1b, 0x01, 0x03, 0x20, 0x0c, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0xff, 0xc0, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00,
  0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0x00, 0x31, 0x35, 0x31,
  0x34, 0x31, 0x33, 0x31, 0x32, 0x0a, 0x20, 0x20, 0x20, 0x20, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x17
};

// MiniCore ATMega328p: https://github.com/MCUdude/MiniCore
// Paperback's Conversion board uses SDA for pin 9 and SCL for pin 10
const int sdaPin = 9;
const int sclPin = 10;
SoftI2CMaster i2c = SoftI2CMaster( sclPin, sdaPin, 1 );

// Real Hardware i2C Port
byte data = -1;
const int i2c_port = 0x50; // i2c Port for Monitor EDID

void setup()
{
  /* Generic pin prep */
  pinMode(SEL_9883, OUTPUT);
  digitalWrite(SEL_9883, LOW);

  pinMode(SW1_OUT, OUTPUT);
  pinMode(SW2_OUT, OUTPUT);
  pinMode(SW3_OUT, OUTPUT);

  /* Setup the *9883 with the above commands */
  i2c.beginTransmission(ADDR9883);
  i2c.write(I2C_REG1);
  delay(50);
  i2c.write(CMD1);
  delay(50);
  i2c.write(CMD2);
  delay(50);
  i2c.write(CMD3);
  delay(50);
  i2c.write(CMD4);
  delay(50);
  i2c.write(CMD5);
  delay(50);
  i2c.write(CMD6);
  delay(50);
  i2c.write(CMD7);
  delay(50);
  i2c.write(CMD8);
  delay(50);
  i2c.write(CMD9);
  delay(50);
  i2c.write(CMD10);
  delay(50);
  i2c.write(CMD11);
  delay(50);
  i2c.write(CMD12);
  delay(50);
  i2c.write(CMD13);
  delay(50);
  i2c.endTransmission();

  /* Listen for VGA source asking for capabilities via EDID */
  Wire.begin(i2c_port);
  Wire.onRequest(gotEvent);
  Wire.onReceive(gotData);
}

void powerOn()
{
  i2c.beginTransmission(ADDR9883);
  i2c.write(POW_REG);
  i2c.write(POW_ON);
  i2c.endTransmission();
}

void powerOff()
{
  i2c.beginTransmission(ADDR9883);
  i2c.write(POW_REG);
  i2c.write(POW_OFF);
  i2c.endTransmission();
}

void gotEvent()
{
  Wire.write(edid, 128);
}


void gotData(int byteCount)
{
  while (Wire.available()) {
    data = Wire.read();
  }
}

/*
 *  The loop handles changes in state of the switches. We're not doing
 *  anything too special here such as overloading the behavior to set
 *  things on the uC. It is just forwarding the state to the *_OUT pins
 *  for consumption by the FPGA.
 */
void loop()
{
  float sw1_voltage = analogRead(SW1)*(3.3 / 1023.0);
  float sw2_voltage = analogRead(SW2)*(3.3 / 1023.0);
  float sw3_voltage = analogRead(SW3)*(3.3 / 1023.0);

  if (sw1_voltage < 1.0) {
    digitalWrite(SW1_OUT,LOW);
  } else {
    digitalWrite(SW1_OUT,HIGH);
  }

  if (sw2_voltage < 1.0) {
    digitalWrite(SW2_OUT,LOW);
  } else {
    digitalWrite(SW2_OUT,HIGH);
  }

  if (sw3_voltage < 1.0) {
    digitalWrite(SW3_OUT,LOW);
  } else {
    digitalWrite(SW3_OUT,HIGH);
  }
}
