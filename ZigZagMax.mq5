//+------------------------------------------------------------------+
//|                                                    ZigZagMax.mq5 |
//|                            Copyright 2022, Diamond Systems Corp. |
//|                                   https://github.com/mql-systems |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Diamond Systems Corp."
#property link      "https://github.com/mql-systems"
#property version   "1.02"
#property indicator_chart_window
//---
#property indicator_buffers 4
#property indicator_plots 3
//---
#property indicator_type1  DRAW_ZIGZAG
#property indicator_label1 "ZigZag Up;ZigZag Down"
#property indicator_color1 clrOrange
//---
#property indicator_type2  DRAW_NONE
#property indicator_label2 "ZigZag Trend"
//---
#property indicator_type3  DRAW_ARROW
#property indicator_color3 clrRed
#property indicator_label3 "ZigZag Trend change"

#include "ZigZagMax.mqh"