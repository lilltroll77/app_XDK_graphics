/*
 * XDKgraphics.xc
 *
 *  Created on: 14 dec 2010
 *      Author: mikael
 */

#include "XDKgraphics.h"
#include "safestring.h"
#include <xs1.h>
#include <xclib.h>
#include "lcd.h"
#include <print.h>

//iso646.h
#define and	&&
#define and_eq	&=
#define bitand	&
#define bitor	|
#define compl	~
#define not	!
#define not_eq	!=
#define or	||
#define or_eq	|=
#define xor	^
#define xor_eq	^=


#define MASK ((1<<PALETTE_LEN)-1)

static inline
void clip(int &val, int min, int max) {
	if (val > max)
		val = max;
	else if (val < min)
		val = min;
}

void box_call(Gbox &obj, Gbuf &buf) {

	int dx, dy, xcenter, ycenter, y, ys;
	int A2, B2, dist;
	unsigned x = buf.lineColumn; //make local
	switch (obj.shape) {
	case rectangle:
		buf.line[x][obj.yposition] = obj.lineColor;
		buf.line[x][obj.yposition + obj.ywidth] = obj.lineColor;
		if (obj.xposition == buf.column || obj.xposition + obj.xwidth
				== buf.column) {
#pragma unsafe arrays
			for (int y = obj.yposition + 1; y < obj.yposition + obj.ywidth; y++)
				buf.line[x][y] = obj.lineColor;
		} else if (obj.fillColor >= 0) {
#pragma unsafe arrays
			for (int y = obj.yposition + 1; y < obj.yposition + obj.ywidth; y++)
				buf.line[x][y] = obj.fillColor;
		}
		break;
	case splitrectangle:
		buf.line[x][obj.yposition] = obj.lineColor;
		buf.line[x][obj.yposition + obj.ywidth] = obj.lineColor;
		if (obj.xposition == buf.column || obj.xposition + obj.xwidth
				== buf.column) {
#pragma unsafe arrays
			for (int y = obj.yposition + 1; y < obj.yposition + obj.ywidth; y++)
				buf.line[x][y] = obj.lineColor;
		} else {
#pragma unsafe arrays
			for (ys = obj.yposition + 1; ys <= obj.yposition + obj.ysplit + 1; ys++)
				buf.line[x][ys] = obj.ysplitColor;// +30+ (ys - obj.yposition)>> 1; //special to be done
#pragma unsafe arrays
			for (ys; ys < obj.yposition + obj.ywidth; ys++)
				buf.line[x][ys] = obj.fillColor;
		}
		break;
	case ellipse:
		A2 = (obj.xwidth * obj.xwidth); //max 17 bitar
		B2 = (obj.ywidth * obj.ywidth);
		xcenter = obj.xposition + obj.xwidth / 2;
		ycenter = obj.yposition + obj.ywidth / 2;
		dx = (buf.column - xcenter) << 9;
		dx *= dx;
		dx /= A2;
		y = obj.yposition;
		do {
			dy = (y - ycenter) << 9;
			dist = dx + dy * dy / B2 - 0xFFFF; //0x10000 if no rounding errors
			y++;
		} while (dist > 0 && y <= ycenter); //search for intersection with ellipse
		for (ys = y; ys <= 2 * ycenter - y; ys++) {
			if (obj.fillColor >= 0)
				buf.line[x][ys] = obj.fillColor;
		}
		if (obj.lineColor >= 0) {
			y--;
			buf.line[x][y] = obj.lineColor;
			buf.line[x][2 * ycenter - y] = obj.lineColor;
			if (obj.yOld - y > 1) {
				for (int yi = y + 1; yi < obj.yOld; yi++) {
					buf.line[x][yi] = obj.lineColor;
					buf.line[x][2 * ycenter - yi] = obj.lineColor; //Use symmetry
				}
			} else if (y - obj.yOld > 1) {
				for (int yi = y - 1; yi > obj.yOld; yi--) {
					buf.line[x][yi] = obj.lineColor;
					buf.line[x][2 * ycenter - yi] = obj.lineColor;//Use symmetry
				}
			}
			obj.yOld = y;
		}
		break;

	}
}

void char_8x6_call(Gchar &Char, Gbuf &buf) {
#pragma unsafe arrays
	for (int y = Char.yposition; y < (Char.yposition + 8); y++) {
		if (1 & (char_map_8x6[Char.character][buf.column - Char.xposition]
				>> (Char.yposition + 7 - y)))
			buf.line[buf.lineColumn][y] = Char.color;
	}
}

void text_8x6_call(Gtext &text, const char str[], Gbuf &buf) {
	int rem, div, yt;
	unsigned ASCII_column;
	unsigned x = buf.lineColumn; //make local
	int j = buf.column - text.xposition;
	switch (text.angle) {
	case horizontal:
		ASCII_column = char_map_8x6[str[j / 6]][j % 6];
#pragma unsafe arrays
		for (int y = 0; y < 8; y++) {
			if ((ASCII_column << y) & 0b10000000)
				buf.line[x][y + text.yposition] = text.color;
		}
		break;
	case vertical:
#pragma unsafe arrays
		for (int row = 0; str[row] != 0; row++) {
			ASCII_column = char_map_8x6[str[row]][j % 6];
			for (int y = 0; y < 8; y++) {
				if ((ASCII_column << y) & 0b10000000) {
					yt = y + text.yposition - 10 * row;
					if (yt >= 0)
						buf.line[x][yt] = text.color;
				}
			}
		}
		break;
	}
}

static inline
void putFramepixel(Gbuf &buf, unsigned x, unsigned y, unsigned colour) {
	int temp;
	int rem = y bitand MASK;
	int div = y>>(6-PALETTE_BITS);
	temp = buf.frame[x][div];
	temp and_eq 0xFFFFFFFF xor ((PALETTE_BITS-1) << (PALETTE_BITS * rem)) ; //Zero the assigned bitfield
	temp or_eq colour << (PALETTE_BITS * rem);
	buf.frame[x][div] = temp;
}

void line(Gbuf &buf) {
	for (int i = 0; i < 240; i += 2)
		putFramepixel(buf, 100, i, 1);
	for (int y = 0; y < 15; y++)
		buf.frame[102][y] = 0x11111111;
}

void textRow_8x6_call_frame(GtextRow &text, Gbuf &buf) {
	unsigned ASCII_column;
	for (int x = 0; x < text.pixelLength; x++) {
		ASCII_column = char_map_8x6[text.str[x / 6]][x % 6]; //The 8*1-bit pixeldata for one row in a character
		for (unsigned y = 0; y < 8; y++) {
			if ((ASCII_column << y) & 0b10000000)
				putFramepixel(buf, x + text.xposition, y + text.yposition,text.color);
		}
	}
}

void textRow_8x6_call_line(GtextRow &text, Gbuf &buf) {
		unsigned x = buf.lineColumn; //make local
		int j = buf.column - text.xposition;
		unsigned ASCII_column = char_map_8x6[text.str[j / 6]][j % 6];
	#pragma unsafe arrays
		for (int y = 0; y < 8; y++) {
			if ((ASCII_column << y) & 0b10000000)
				buf.line[x][y] = text.color;
		}
}

void initGtextrow(GtextRow &text){
	text.pixelLength=6*safestrlen(text.str);
	if(text.type==framebuffer and text.color>=PALETTE_LEN){
		printstrln("ERROR: PALETTE INDEX IS GREATER THAN PALETTE LENGT - PROGRAM HALTED");
		while(1);
	}
}

void initGtext(Gtext &text, const char str[]) {
	switch (text.angle) {
	case horizontal:
		text.pixelLength = 6 * safestrlen(str);
		break;
	case vertical:
		text.pixelLength = 6;
		break;
	}
}

