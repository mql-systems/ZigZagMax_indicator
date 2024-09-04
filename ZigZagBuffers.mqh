//###<Indicators/AT/ZigZagMax/ZigZagMax.mq5>
//+------------------------------------------------------------------+
//|                                                ZigZagBuffers.mq4 |
//|                       Copyright 2022-2024, Diamond Systems Corp. |
//|               https://github.com/mql-systems/ZigZagMax_indicator |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022-2024, Diamond Systems Corp."
#property link      "https://github.com/mql-systems/ZigZagMax_indicator"
#property strict

#define ZZM_BUFFER_EMPTY                  0.0
#define ZZM_BUFFER_TREND_UP               1.0
#define ZZM_BUFFER_TREND_UP_DOWN          2.0
#define ZZM_BUFFER_TREND_UP_ENGULFING     3.0
#define ZZM_BUFFER_TREND_DOWN            -1.0
#define ZZM_BUFFER_TREND_DOWN_UP         -2.0
#define ZZM_BUFFER_TREND_DOWN_ENGULFING  -3.0

enum ENUM_ZZM_TREND
{
   ZZM_TREND_ERROR = -1,
   ZZM_TREND_NONE,
   ZZM_TREND_UP,
   ZZM_TREND_DOWN,
   ZZM_TREND_UP_DOWN,
   ZZM_TREND_DOWN_UP,
   ZZM_TREND_UP_ENGULFING,
   ZZM_TREND_DOWN_ENGULFING,
};

//+------------------------------------------------------------------+
//| Structure CZigZagBuffers                                         |
//| Usage: storage of buffer data                                    |
//+------------------------------------------------------------------+
struct CZigZagBuffers
{
   double   bufferUp[];
   double   bufferDown[];
   double   bufferMaxChangePoints[];
   double   bufferTrend[];
   //---
   datetime firstBarTime;
   datetime lastBarTime;
   int      firstBarIndex;
   //---
   int      pointBarLast;
   int      pointBarUp;
   int      pointBarDown;
   //---
   bool     seriesFlag;
   //---
   void     CZigZagBuffers(void) : seriesFlag(true) {}
   bool     IsInitialize(const datetime &time[], const int newBarCnt);
   void     UpdatePointBars(const int newBarCnt);
   void     Set(const int i, ENUM_ZZM_TREND trend);
   void     Clear(void);
};

/**
 * Checks whether it is necessary to index and start the calculation again
 * 
 * @param  time: Array with timeseries
 * @param  newBarCnt: Number of new bars
 * @return ( bool )
 */
bool CZigZagBuffers::IsInitialize(const datetime &time[], const int newBarCnt)
{
   if (time[1] != lastBarTime)
      return (time[newBarCnt + 1] != lastBarTime);
   else 
      return (time[firstBarIndex] != firstBarTime);
}

/**
 * Update the index of the latest ZigZag points
 * 
 * @param  newBarCnt: Number of new bars
 */
void CZigZagBuffers::UpdatePointBars(const int newBarCnt)
{
   pointBarLast += newBarCnt;
   pointBarUp += newBarCnt;
   pointBarDown += newBarCnt;
}

void CZigZagBuffers::Set(const int barIndex, ENUM_ZZM_TREND trend)
{
   bufferUp[barIndex] = ZZM_BUFFER_EMPTY;
   bufferDown[barIndex] = ZZM_BUFFER_EMPTY;
   bufferMaxChangePoints[barIndex] = ZZM_BUFFER_EMPTY;

   switch (trend)
   {
      case ZZM_TREND_ERROR:
      case ZZM_TREND_NONE:
         bufferTrend[barIndex] = ZZM_BUFFER_EMPTY;
         return;
      case ZZM_TREND_UP:
         pointBarDown = barIndex;
         // ZigZagBuffers.bufferUp[barIndex] = ZZM_BUFFER_EMPTY;
         // ZigZagBuffers.bufferDown[barIndex] = low[barIndex];
         // ZigZagBuffers.bufferTrend[barIndex] = ZZM_BUFFER_TREND_DOWN;
        break;
//      case ZZM_TREND_DOWN:
//         break;
//      case ZZM_TREND_UP_DOWN:
//         break;
//      case ZZM_TREND_DOWN_UP:
//         break;
//      case ZZM_TREND_UP_ENGULFING:
//         break;
//      case ZZM_TREND_DOWN_ENGULFING:
//         break;
      
      default:
         break;
   }

   bufferMaxChangePoints[barIndex] = low[barIndex];
   pointBarLast = barIndex;
}

void CZigZagBuffers::SetUp(const int barIndex, const double price)
{
   bufferUp[barIndex] = bufferMaxChangePoints[barIndex] = price;
   bufferDown[barIndex] = ZZM_BUFFER_EMPTY;
   bufferTrend[barIndex] = ZZM_BUFFER_TREND_UP;
}

void CZigZagBuffers::Clear(void)
{
   firstBarTime = lastBarTime = firstBarIndex = pointBarLast = pointBarUp = pointBarDown = 0;

   ArrayInitialize(ZigZagBuffers.bufferUp, ZZM_BUFFER_EMPTY);
   ArrayInitialize(ZigZagBuffers.bufferDown, ZZM_BUFFER_EMPTY);
   ArrayInitialize(ZigZagBuffers.bufferMaxChangePoints, ZZM_BUFFER_EMPTY);
   ArrayInitialize(ZigZagBuffers.bufferTrend, ZZM_BUFFER_EMPTY);

   ArraySetAsSeries(ZigZagBuffers.bufferUp, seriesFlag);
   ArraySetAsSeries(ZigZagBuffers.bufferDown, seriesFlag);
   ArraySetAsSeries(ZigZagBuffers.bufferMaxChangePoints, seriesFlag);
   ArraySetAsSeries(ZigZagBuffers.bufferTrend, seriesFlag);
}
