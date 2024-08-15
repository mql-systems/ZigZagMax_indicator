//+------------------------------------------------------------------+
//|                                                    ZigZagMax.mq5 |
//|                       Copyright 2022-2024, Diamond Systems Corp. |
//|               https://github.com/mql-systems/ZigZagMax_indicator |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022-2024, Diamond Systems Corp."
#property link      "https://github.com/mql-systems/ZigZagMax_indicator"
#property version   "1.00"
#property indicator_chart_window
//---
#property indicator_buffers 4
#property indicator_plots 2
//---
#property indicator_type1  DRAW_ZIGZAG
#property indicator_label1 "ZigZag Up;ZigZag Down"
#property indicator_color1 clrOrange
//---
#property indicator_type2  DRAW_ARROW
#property indicator_color2 clrNONE
#property indicator_label2 "ZigZag Max Change Points"

#include "ZigZagMax.mqh"