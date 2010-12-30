/*
 * XDKgraphics.xc
 *
 *  Created on: 14 dec 2010
 *      Author: mikael
 */

#include "XDKgraphics.h"
#include "safestring.h"
#include <xs1.h>

//#define INLINE

static inline
void clip(int &val,int min,int max){
	if(val>max)
		val=max;
	else if(val<min)
		val=min;
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
				buf.line[x][ys] = 30 + obj.ysplitColor + (ys - obj.yposition)
						>> 1; //special
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
	unsigned x = buf.lineColumn; //make local
	int j = buf.column - text.xposition;
	switch (text.angle) {
	case horizontal:
		rem = j % 6;
		div = j / 6;
#pragma unsafe arrays
		for (int y = text.yposition; y < (text.yposition + 8); y++) {
			if (1 & (char_map_8x6[str[div]][rem] >> (text.yposition + 7 - y)))
				buf.line[x][y] = text.color;
		}
		break;
	case vertical:
#pragma unsafe arrays
		for (int row = 0; str[row] != 0; row++) {
			for (int y = text.yposition; y < (text.yposition + 8); y++) {
				yt = y - 10 * row;
				if (1 & (char_map_8x6[str[row]][j] >> (text.yposition + 7 - y))
						&& yt >= 0)
					buf.line[x][yt] = text.color;
			}
		}
		break;
	}
}



void textRow2FrameBuf(GtextRow &text, Gbuf &buf){
for (int x = 0 ; x<text.pixelLength ; x++){
	for (int y = 0 ; y <8 ; y++ ) {
		if( (char_map_8x6[text.str[x/6]][x%6]&(1<<(7-y)))>0)
		buf.frame[x+text.xposition][(text.yposition)>>4 ]|= (text.color<<(2*y+(text.yposition%16)));
		}
	}
}


void textRow_8x6(GtextRow &text, Gbuf &buf) {
if (text.xposition <= buf.column && buf.column < text.xposition + text.pixelLength) {
		int rem, div;
		unsigned x=buf.lineColumn; //make local
		int j = buf.column - text.xposition;
			rem = j % 6;
			div = j / 6;
#pragma unsafe arrays
			for (int y = text.yposition; y < (text.yposition
					+ 8); y++) {
				if (1 & (char_map_8x6[text.str [div]][rem]
						>> (text.yposition + 7 - y)))
					buf.line[x][y] = text.color;
			}
	}
}

void setPixellength(Gtext &text,const char str[]) {
	switch (text.angle) {
	case horizontal:
		text.pixelLength = 6 * safestrlen(str);
		break;
	case vertical:
		text.pixelLength = 6;
		break;
	}
}
