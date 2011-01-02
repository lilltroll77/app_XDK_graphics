/*
 * lcdDriver.h
 *
 *  Created on: 29 nov 2010
 *      Author: mikael
 *      TO BE DONE:
 *      This ver. is based on structs const struct to avoid asm pointers. Const struct will probably be
 *      prohibited in XDE version above 10. The struct must then handle memory pointers instead
 */


#ifndef LCDDRIVER_H_
#define LCDDRIVER_H_

#include "platform.h"

//If the screens flickers, check that it isn't running far below 5 MHz
//If the pixels are inccorect of the beginning of a new frame or a new line, you should probably increase the delays
#define T_HFP                 750 //delay connected with Hsync may be decreased
#define T_HBP                 650 //delay connected with Hsync may be decreased
#define T_WH                  350	//delay connected with DTMG may be decreased
#define T_VBP                 10000	//100us delay before each frame
#define LCD_CLKDIV            10	//  100/2/(10)= 5.00 MHz clock, do not go below 9 e.g. 5.55 MHz, driver will be starved out of time

#define LINES 4				//The amount of lines used in the linebuffer, 320/LINES should not result in a reminder in this release
#define LCD_WIDTH_PX 240 	//Adopted from XMOS, this is the short LCD side
#define LCD_HEIGHT_PX 320 	//Adopted from XMOS, this is the long LCD side
#define PALETTE_BITS 2		//The bit-size of the palette. Possible values are 1,2,(4) uses 9.6, 19.2, 38.4 kB SRAM

#define PALETTE_LEN (1<<PALETTE_BITS)
enum CT {CT_STARTserver=20,CT_serverRunning=21,CT_STOPserver=0, CT_RequestData=1,CT_serverKilled=-1};

typedef const struct{
	unsigned palette[PALETTE_LEN];
	unsigned column;
	unsigned lineColumn;
	unsigned line[LINES][LCD_WIDTH_PX];
	unsigned frame[LCD_HEIGHT_PX][ LCD_WIDTH_PX>>(6-PALETTE_BITS)];
}Gbuf;

struct lcd {
	out port p_hsync;
	out port p_dtmg;
	out port p_dclk;
	out port p_rgb;
	clock c_lcd;
	};


void lcdDriver(struct lcd &r,Gbuf &buf,streaming chanend c_column);
void initBuf(Gbuf &buf);
#endif /* LCDDRIVER_H_ */
