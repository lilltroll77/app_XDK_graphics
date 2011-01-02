/*
 * lcdDriver.xc
 *
 *  Created on: 29 nov 2010
 *      Author: mikael
 */

/*
 *  LCD Server thread (no sram)
 */

#include <xs1.h>
#include "lcd.h"
#include "XDKgraphics.h"

#define MASK ((1<<PALETTE_LEN)-1)

void initBuf(Gbuf &buf){
//init the framebuffer
	for (int y = 0; y < LCD_WIDTH_PX>>(6-PALETTE_BITS); y++)
		for (int x = 0; x < LCD_HEIGHT_PX; x++)
			buf.frame[x][y] = 0;
}


void lcdDriver(struct lcd &r,Gbuf &buf, streaming chanend c_Column) {
	timer t;
	int isRunning=1;
	unsigned temp;
	unsigned char ct;
	unsigned time, BufX;
	// Initialise physical interface
	set_clock_div(r.c_lcd, LCD_CLKDIV);
	set_port_inv(r.p_dclk);
	r.p_hsync <:0;
	r.p_dclk <: 0;
	set_port_clock(r.p_hsync, r.c_lcd);
	set_port_clock(r.p_dclk, r.c_lcd);
	set_port_clock(r.p_dtmg, r.c_lcd);
	set_port_clock(r.p_rgb, r.c_lcd);

	// Set to outclock mode
	set_port_mode_clock(r.p_dclk);
	schkct(c_Column,CT_STARTserver);
	ct=CT_serverRunning;
	soutct(c_Column,ct);
	start_clock(r.c_lcd);
	do{
		t:>time;
		select{
		case c_Column:>isRunning:
		break;
		default:
		t when timerafter(time+T_VBP) :> time;
#pragma unsafe arrays
		for( int x=0;x < LCD_HEIGHT_PX;){
			t:>time;
			BufX=x%LINES;
			t when timerafter(time+T_WH) :> time;
			r.p_hsync <: 1;
			t when timerafter(time+T_HBP) :> int _;
			r.p_dtmg <: 1;
#pragma unsafe arrays
			if(isRunning){
				//Do not use / or % inside this loop. It is shared between threads and might be delayed
				for(int y=0; y <LCD_WIDTH_PX; y++){
					if((y&MASK)==0)
						temp=(buf.frame[x][y>>(6-PALETTE_BITS)]);
					else
						temp>>=PALETTE_BITS;
					r.p_rgb<:buf.line[BufX][y]^buf.palette[temp&(PALETTE_LEN-1)]; //Read the linbuffer and XOR it with the LSB log2(PALETTE_LEN) bits
				}
			}else
				for(unsigned y=0; y <LCD_WIDTH_PX; y++)
					r.p_rgb<:0; //All pixels should be set to Black before killing the server, othervise fading colours will remain on the LCD

			c_Column<:++x; //Request rendering a new line
			r.p_dtmg <: 0;
			r.p_rgb<:0; //Avoid overshoot at next line
			t :> time;
			t when timerafter( time + T_HFP) :> time;
			r.p_hsync <:0;
		}
		break;
		}
	}while(isRunning);
	c_Column<:CT_serverKilled; //Tell the client that
	set_port_use_off(r.p_dclk);
	set_port_use_off(r.p_dtmg);
	set_port_use_off(r.p_rgb);
	set_port_use_off(r.p_hsync);
	set_clock_off(r.c_lcd);
}
