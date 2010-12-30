/**
 * Module:  touch_screen
 * Version: 1v1
 * Build:   b454f88b0e425ad38993188bdace5bbbcdf50276
 * File:    touch.xc
 *
 * The copyrights, all other intellectual and industrial 
 * property rights are retained by XMOS and/or its licensors. 
 * Terms and conditions covering the use of this code can
 * be found in the Xmos End User License Agreement.
 *
 * Copyright XMOS Ltd 2010
 *
 * In the case where this code is a modification of existing code
 * under a separate license, the separate license terms are shown
 * below. The modifications to the code are still covered by the 
 * copyright notice above.
 *
 **/

/*Modified by Mikael Bohman 2010 to use streaming chan since both LCD and A/D are located on the same core*/

#include <xs1.h>
#include <platform.h>
#include <xclib.h>
#include "lcd.h"

// Touchscreen ADC ports/ clock block
on stdcore[3] : in port p_tou_pen       = PORT_TOUCH_PEN;         // Pen Interupt
on stdcore[3] : in port p_tou_dout      = PORT_TOUCH_DOUT;        // DOUT (ADC -> Xcore)
on stdcore[3] : out port p_tou_cs       = PORT_TOUCH_CS;
on stdcore[3] : out port p_tou_dclk     = PORT_TOUCH_DCLK;
on stdcore[3] : out port p_tou_din      = PORT_TOUCH_DIN;         // DIN (Xcore -> ADC)
on stdcore[3] : clock clk_tou           = XS1_CLKBLK_2;


#define Xoffset -8
#define Yoffset -8

#define CMD_POS         0x0
#define CMD_COLOUR      0x1
#define CMD_KILL        0x2

unsigned doADCTransaction(unsigned controlReg);
{unsigned,unsigned} getTouchScreenPos();

	/** Main program loop
	 * @param chanend c channel to cross position keeper
	 * @brief The main program thread.  This thread waits for an user pressing the screen event, reads the position from the touchscreen
	 * and uses channels to output this position to the "position keeper" thread
	 * @return void
	 */
	void touch(streaming chanend c_tou) {
		int tmp = 0, tmpx = 1, tmpy = 1;
		unsigned active = 1;

		// Setup touchscreen/adc ports
		set_clock_div(clk_tou, 50);
		start_clock(clk_tou);
		set_port_clock(p_tou_dclk, clk_tou);
		set_port_clock(p_tou_din, clk_tou);
		set_port_clock(p_tou_dout, clk_tou);

		p_tou_cs <: 1;
		p_tou_dclk <: 0;

		schkct(c_tou, CT_STARTserver);
		soutct(c_tou, CT_serverRunning);
		// Main loop
		while(active)
		{
			c_tou :> active;
			p_tou_pen:>tmp;
			if(tmp==0)
				{tmpx, tmpy}= getTouchScreenPos();
			c_tou <: tmp;
			c_tou <:(unsigned short) tmpx;
			c_tou <:(unsigned short) tmpy;


		}

		set_port_use_off(p_tou_dout);
		set_port_use_off(p_tou_din);
		set_port_use_off(p_tou_dclk);
		set_clock_off(clk_tou);

	}


/** doADCTransaction
  * @brief Sends commands to ADC and returns relevant data (using SPI)
  */
unsigned doADCTransaction(unsigned controlReg)
{
  unsigned returnVal = 0;
  int i;

  p_tou_cs <: 0;

  controlReg=bitrev(controlReg);
  controlReg=controlReg >> 25;

  p_tou_dclk <: 0;

  // Start bit
  p_tou_din <: 1;
  p_tou_dclk <: 1;

  for(i = 0; i< 7; i+=1)
  {
    p_tou_dclk <: 0;
    p_tou_din <: >> controlReg;
    p_tou_dclk <: 1;
  }

  //Busy clock.  .
  p_tou_dclk <:0;
  p_tou_dclk <:1;

  // TODO: check control reg val to see how many bits to clock in
  // Currently only using 8-bit mode...
  for(i = 0; i < 8; i+=1)
  {
    p_tou_dclk <: 0;
    p_tou_dclk <: 1;
    sync(p_tou_dclk);
    p_tou_dout :> >> returnVal;
  }

  p_tou_cs <: 1;
  p_tou_dclk <: 0;

  return bitrev(returnVal) ;
}


/** getTouchScreenPos
  * @brief Uses doADCTransaction function to get X and Y positions
  * Note the nice use of XC multiple return values for X and Y data
  * Also note: this is probably the main resuable interface this demo app provides
  */
{unsigned, unsigned} getTouchScreenPos()
{
  unsigned returnValX;
  unsigned returnValY;

  // 8 bit/single ended/power up  Y:0x1e  X:0x5e
  // 8 bit/differential/power up  Y:0x1a  X:0x5a
  returnValY = doADCTransaction(0x1a)+Yoffset;
  returnValX = doADCTransaction(0x5a)+Xoffset;

  // Physical screen resolution is 240 X 320, ADC resolution (8 bit) is 255 * 255.  Do simple scaling and bounds check
  returnValY = (returnValY * 350) >> 8;


  if (returnValY > 320)
      returnValY = 320;

  if (returnValX > 240)
    returnValX = 240;

  return {returnValY, returnValX};
}
