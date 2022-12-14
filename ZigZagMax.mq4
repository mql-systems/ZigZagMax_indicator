//+------------------------------------------------------------------+
//|                                                    ZigZagMax.mq4 |
//|                            Copyright 2022, Diamond Systems Corp. |
//|                                   https://github.com/mql-systems |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Diamond Systems Corp."
#property link      "https://github.com/mql-systems"
#property version   "1.02"
#property indicator_chart_window
//---
#property indicator_buffers 3
#property indicator_type1 DRAW_ZIGZAG
#property indicator_type2 DRAW_ZIGZAG
#property indicator_type3 DRAW_NONE
#property indicator_color1 clrOrange
#property indicator_color2 clrOrange
#property indicator_label1 "ZigZag Up"
#property indicator_label2 "ZigZag Down"
#property indicator_label3 "ZigZag Trend"

#include "ZigZagMax.mqh"