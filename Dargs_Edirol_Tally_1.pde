// http://timothytwillman.com/itp_blog/zf
// using what i've renamed 'midi2' library
// compiled in Arduino 0019 (not 21 or 22 - reports 'Serial' ?)
//
// It's necessary to subclass Midi in order to handle receiving messages.  If
//  you're only sending data, see MidiSendExample, which is a bit simpler.
//
// If you're both sending AND receiving you'll need to subclass like this,
//  but only for receive functions.
//
// Swapped line 462~  shift out standby tallys after onairs, to fix my db9 mis-wire


#include "Midi.h"

#include <LiquidCrystal.h> // we need this library for the LCD commands
LiquidCrystal lcd(13, 8, 9, 10, 11, 12);  // changing pin RS to 13 instead of 5

int latchpin = 3; // connect to pin 12 on the '595
int clockpin = 4; // connect to pin 11 on the '595
int datapin = 5; // connect to pin 14 on the '595

#define STAT1  7 // stat leds
#define STAT2  6 



//       (LCD pin 1 GND
//       (LCD pin 2 +5v
//       (LCD pin 3 Variable
// 13=RS  (LCD Pin 4)
//       (LCD pin 5) RW to GND
// 8=E   (LCD Pin 6)
// 9=DB4 (LCD pin 11)

// 10=DB5 (LCD pin 12)
// 11=DB6 (LCD pin 13)
// 12=DB7 (LCD pin 14)
// (LCD pin 15 Backlight +5v
// (LCD pin 16 Backlight GND

int tally[8]={0,0,0,0,0,0,0,0}; // 8 bytes to store true/false of each tally status
int tallyb[8]={0,0,0,0,0,0,0,0}; // 8 bytes to store true/false of each tally status
int busa; // bus A source 1-8
int busb; // bus B source 1-8
int ftb; // fade to black (CC 4) 0 for value=0, 1 for value<0
int tbar; // transistion bar (CC 3) 
int transA; // Transformer A (CC 7 Value 0 or 127)
int transB; // Transformer B (CC 8 Value 0 or 127)

// tbar = 0 busA only (value 0)
// tbar = 1 busB only (value 127)
// tbar = 2 busA + bus B (value>0 & value<127) ie between 1 and 126 is both bus'


// To use the Midi class for receiving Midi messages, you need to subclass it.
//  If you're a C++ person this makes sense; if not, just follow the example
//  functions below.
//
// Basically, MyMidi here can do anything Midi can do -- it just has the ability
//  to easily change what the functions do when different message types are received.
//
class MyMidi : public Midi {
  public:
  
  // Need this to compile; it just hands things off to the Midi class.
  MyMidi(HardwareSerial &s) : Midi(s) {}
  

void handleControlChange(unsigned int channel, unsigned int controller, unsigned int value)
{

/*
if Control Change = 1 then  make busa=that value
if Control Channge =2  then  make busb=that value
*/
 if (controller==1) 
   {
   busa=value;
   }

 if (controller==2) 
   {
     busb=value;
   }

 if (controller==4 & value==0)
  {
    ftb=0;
  }
  if (controller==4 & value>0)
  {
    ftb=1;
  }
  
/* 
if control change = 4 then, if value=0 then ftb = 0 else ftb=1
*/

/*
if control change = 3 then, tbar 
tbar = 0 busA only (value 0)
tbar = 1 busB only (value 127)
tbar = 2 busA + bus B (value>0 & value<127) ie between 1 and 126 is both bus'
*/

if (controller==3) // tbar
  {
    if (value==0)
      {
        tbar=0;
      }
    if (value==127)
      {
        tbar=1;
      }
    if (value>0 & value<127)
      {
        tbar=2;
      } 
  }

if (controller==7) // transformer A
  {
    if (value==0)
      {
        transA=0;
      }
    if (value==127)
      {
        transA=1;
      }
  }

if (controller==8) // transformer B
  {
    if (value==0)
      {
        transB=0;
      }
    if (value==127)
      {
        transB=1;
      }
  }



for (int x=0; x<8; x++)
    {
      tally[x]=0; // clears all tallys for a split second before updating
    }

for (int x=0; x<8; x++)
    {
      tallyb[x]=0; // clears all standby tallys for a split second before updating
    }


if (ftb==1 & tbar==0 & transA==0 & transB==0)
  {
   tally[busa]=1;
   if (busa != busb) // if Bus A is differnet to Bus B turn on bus B standby tally 
   {   tallyb[busb]=1;  // standby tally
   }
  }
  
if (ftb==1 & tbar==1 & transA==0 & transB==0)
  {
   tally[busb]=1;
   if(busa!=busb) // if Bus A is differnet to Bus B turn on bus A standby tally 
   {
   tallyb[busa]=1;  // standby tally
   }
  }
  
if (ftb==1 & tbar==2 & transA==0 & transB==0)
  {
   tally[busa]=1;
   tally[busb]=1;
  }
  
if (ftb==1 & transA==1 )
  {
   tally[busa]=1;
   if (busa != busb) // if Bus A is differnet to Bus B turn on bus B standby tally 
   {   
     tallyb[busb]=1;  // standby tally
   }
  }

if (ftb==1 & transB==1 )
  {
   tally[busb]=1;
   
    if (busa != busb) // if Bus A is differnet to Bus B turn on bus B standby tally 
   {   
     tallyb[busa]=1;  // standby tally
   }
  }
  

if (ftb==0 & transA==1 )
  {
   tallyb[busa]=1;  // if fadetoblack is @ 0 and Transformer A is held, bus[a] is on Standby
   
   
  }

if (ftb==0 & transB==1 )
  {
   tallyb[busb]=1;  // standby tally
  }
  
if (ftb==0 & tbar==0 & transA==0 & transB==0)
  {
   tallyb[busa]=1;   // standby tally
  }

if (ftb==0 & tbar==1 & transA==0 & transB==0)
  {
   tallyb[busb]=1;   // standby tally
  }

if (ftb==0 & tbar==2 & transA==0 & transB==0)
  {
   tallyb[busa]=1;   // standby tally
   tallyb[busb]=1;   // standby tally
  }
  

/* 

tally(x) clear tallys * work out some way to check which ones are on, and see if they stay on or off
// change it to a Old tally vs New tally thing


   if ftb=1 & tbar=0, make tally(busA)=1 
   if ftb=1 & tbar=1, make tally(busB)=1 
   
  if ftb=1 & tbar=2, make tally(busA)=1, tally(busB)=1
*/




    Lcd_Display_debug(channel, controller, value);

    SetTallys();
  }
  
};


MyMidi midi(Serial);


void setup() 
{

pinMode(STAT1,OUTPUT);   
pinMode(STAT2,OUTPUT);

pinMode(latchpin, OUTPUT);
pinMode(clockpin, OUTPUT);
pinMode(datapin, OUTPUT);

attachInterrupt(0, menu, RISING); // so when interrupt zero (digital pin 2) changes state, it will trigger the interrupt and go to function 'menu'

SetTallys(); // sends 0's the shift registers on bootup.


lcd.begin(16, 2); // tells Arduino the LCD dimensions

lcd.setCursor(0,0);
//         1234567891123456
lcd.print("* Dargstronix  *"); // print text and move cursor to start of next line
lcd.setCursor(0,1);
lcd.print("* Edirol Tally *");
delay(2000);

lcd.clear(); // clear LCD screen
//         1234567891123456
lcd.print("* Version 1.1  *"); // print text and move cursor to start of next line
lcd.setCursor(0,1);
lcd.print("* 6 March 2011 *");
delay(3000);

lcd.clear(); // clear LCD screen
lcd.print("   Testing LEDs   "); 
lcd.setCursor(0,1);
lcd.print("                  ");

for(int i=0; i<255;i++) // bit of flashy flash
  {
     digitalWrite(latchpin, LOW);  

     shiftOut(datapin, clockpin, MSBFIRST, i);
     shiftOut(datapin, clockpin, MSBFIRST, i);
     shiftOut(datapin, clockpin, MSBFIRST, i);
     
     digitalWrite(latchpin, HIGH);      
     delay(15);
  }

lcd.clear(); // clear LCD screen
lcd.print("   waiting for   "); 
lcd.setCursor(0,1);
lcd.print("    MIDI data     ");


/*
  for(int i = 0;i < 10;i++) // flash MIDI Sheild LED's on startup
  {
    digitalWrite(STAT1,HIGH);  
    digitalWrite(STAT2,LOW);
    delay(30);
    digitalWrite(STAT1,LOW);  
    digitalWrite(STAT2,HIGH);
    delay(30);
  }
  digitalWrite(STAT1,HIGH);   
  digitalWrite(STAT2,HIGH);
*/

   
  // This causes the midi object to listen to ALL Midi channels.  If a number
  //  from 1-16 is passed, messages will be filtered so that any messages to
  //  channels other than the given one will be ignored.
  //
  // Note that you can pass a second parameter as a baud rate, if you're doing
  //  Midi protocol but using some other communication method (e.g. sending
  //  Midi data from Max/MSP using the standard Arduino USB connection, you
  //  can set the baud rate to something more standard and use the regular
  //  Max serial object)

  midi.begin(0);

}


void loop()
{
  // Must be called every time through loop() IF dealing with incoming MIDI --
  //  if you're just sending MIDI out, you don't need to use poll().
  //
  // Make sure other code doesn't take too long to process or serial data
  //  can get backed up (and you can end up with obnoxious latency that ears
  //  don't like).
  //
  // The poll function will cause the midi code to suck data from the serial 
  //  port and process it, and call any functions that are defined for handling
  //  midi messages.
  midi.poll();
}


void Lcd_Display_debug(unsigned int channel, unsigned int controller, unsigned int value)
{
// lcd.clear(); // clear LCD screen 

lcd.setCursor(0,0);
lcd.print("F");
lcd.setCursor(1,0);
lcd.print(ftb);
lcd.print(" ");
lcd.setCursor(3,0);
lcd.print("T");
lcd.setCursor(4,0);
lcd.print(tbar);
lcd.print("    ");

lcd.setCursor(9,0);
lcd.print("C");
lcd.setCursor(10,0);
lcd.print(controller);
lcd.print(" ");

lcd.setCursor(12,0);
lcd.print("V");
lcd.setCursor(13,0);
lcd.print(value);
lcd.print("   ");

  for (int x=0; x<8; x++)
    {
      lcd.setCursor(x,1);
      lcd.print(tally[x]); // should print "00000000" on bottom row
    }
lcd.print(" ");

lcd.setCursor(9,1); // line 2
lcd.print("A:");
lcd.setCursor(11,1); // line 2
lcd.print(busa+1);
lcd.print(" ");

lcd.setCursor(13,1); // line 2
lcd.print("B:");
lcd.print(busb+1);


// 0123456789112345
// cont: 2____val_6
// ________A_0_B_0_
// 01234567_Cx_Vxxx
// xxxxxxxx_A:x_B:x

}


void SetTallys()
{

  int base2; // variable used to add the tally array items (0s or 1s) to make a variable to feed to the 74HC595
  int base2b; // variable used to add the standby tally array

//            1           2                 4                 8                 16                32                64                128
base2 = tally[0] + (tally[1] << 1) + (tally[2] << 2) + (tally[3] << 3) + (tally[4] << 4) + (tally[5] << 5) + (tally[6] << 6) + (tally[7] << 7 ) ; // on Air 
base2b = tallyb[0] + (tallyb[1] << 1) + (tallyb[2] << 2) + (tallyb[3] << 3) + (tallyb[4] << 4) + (tallyb[5] << 5) + (tallyb[6] << 6) + (tallyb[7] << 7 ) ; // standby

     digitalWrite(latchpin, LOW);
     shiftOut(datapin, clockpin, MSBFIRST, base2); // send On Air for RJ45 outputs - Last Shift Register
     shiftOut(datapin, clockpin, MSBFIRST, base2);  // send ON AIR tally to first shift register 
     shiftOut(datapin, clockpin, MSBFIRST, base2b); // send standby tally to middle shift register in the chain
     
     digitalWrite(latchpin, HIGH);      
}

void menu()
{
lcd.clear();
//         1234567891123456  
lcd.print("* BEER-O-CLOCK *");

// here will be a menu

// maybe to x-patch the outputs?
// change midi settings ?
// help ?f

}
