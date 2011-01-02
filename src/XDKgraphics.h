/*
 * XDKgraphics.h
 *
 *  Created on: 14 dec 2010
 *      Author: mikael
 */
//#define INLINE

#ifndef XDKGRAPHICS_H_
#define XDKGRAPHICS_H_
#include "charmap.h"
#include "lcd.h"



// Some useful colour defines for the line buffer
#define LCD_WHITE             0x3ffff
#define LCD_GREY              0x0f3cf
#define LCD_BLACK             0x00000
#define LCD_RED               0x0003f
#define LCD_GREEN             0x00fc0
#define LCD_BLUE              0x3f000
#define LCD_YELLOW            0x0ffff
#define LCD_TEAL              0x3ffc0

// Some useful colour defines for the frame buffer

#define LCD_TRANSPARENT		  -1
#define LCD_INVERT			  0x3ffff
#define LCD_INVERT_RED		  0x3f
#define LCD_INVERT_GREEN	  0x00fc0
#define LCD_INVERT_BLUE	  	  0x3f000
#define LCD_INVISIBLE		  0


enum dir {horizontal,vertical};
enum shape {rectangle,ellipse,splitrectangle};


typedef struct{
	short xposition;
	short yposition;
	int color;
	enum dir angle;
	unsigned pixelLength;
}Gtext;

typedef struct{
	enum shape shape;
	unsigned short xposition;
	unsigned short yposition;
	unsigned short xwidth;
	unsigned short ywidth;
	int lineColor;
	int fillColor;
	int ysplitColor;
	unsigned short ysplit;
	unsigned short yOld; //Internal state for interpolation
}Gbox;

typedef struct{
	unsigned short xposition;
	unsigned short yposition;
	char str[52];
	int color;
	unsigned short pixelLength;
}GtextRow;

typedef struct{
	int color;
	unsigned short xposition;
	unsigned short yposition;
	char character;
}Gchar;

void text_8x6_call(Gtext &text,const char str[], Gbuf &buf );
void char_8x6_call(Gchar &Char, Gbuf &buf);
void box_call(Gbox &obj, Gbuf &buf);
void textRow_8x6(GtextRow &text, Gbuf &buf);
void textRow2FrameBuf(GtextRow &text, Gbuf &buf);
void line(Gbuf &buf);

static inline
void updateLineHandler(Gbuf &buf){
	buf.column+=(LINES-1);
	buf.column%=LCD_HEIGHT_PX;
	buf.lineColumn=buf.column%LINES;
}

static inline
void drawBackground(Gbuf &buf,int colour){
#pragma unsafe arrays
	for(int y=0;y<LCD_WIDTH_PX;y++)
		buf.line[buf.lineColumn][y]=colour;
}


static inline
void text_8x6(Gtext &text,const char str[], Gbuf &buf ) {
	if (text.xposition <= buf.column && buf.column < text.xposition + text.pixelLength)
		text_8x6_call(text,str,buf);
}

static inline
void char_8x6(Gchar &Char, Gbuf &buf){
	if (Char.xposition <= buf.column && buf.column < Char.xposition + 6)
		char_8x6_call(Char,buf);
}

static inline
void box(Gbox &obj, Gbuf &buf ) {
	if ((obj.xposition <= buf.column) && (buf.column <= obj.xposition + obj.xwidth))
		box_call(obj,buf);
}

void setPixellength(Gtext &text,const char str[]);

#endif /* XDKGRAPHICS_H_ */
