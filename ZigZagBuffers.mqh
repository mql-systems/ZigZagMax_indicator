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

enum ENUM_ZZM_TREND_DIRECTION
{
   ZZM_TREND_DIRECTION_UP   = 1,
   ZZM_TREND_DIRECTION_DOWN = 2,
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
   ENUM_ZZM_TREND_DIRECTION lastTrend;
   //---
   int      pointBarLast;
   int      pointBarUp;
   int      pointBarDown;
   //---
   bool     seriesFlag;
   //---
   void     CZigZagBuffers(void) : seriesFlag(true) {}
   bool     IsInitialize(const datetime &time[], const int newBarCnt);
   void     FixCalcTime(const int ratesTotal, const datetime &time[]);
   void     UpdatePointBars(const int newBarCnt);
   void     Clear(void);
   //---
   bool     IsLastTrendUp(void);
   bool     IsLastTrendDown(void);
   double   GetLastUp(void);
   double   GetLastDown(void);
   //---
   void     SetUp(const int barIndex, const double price);
   void     SetDown(const int barIndex, const double price);
   void     SetUpDown(const int barIndex, const double high, const double low);
   void     SetDownUp(const int barIndex, const double high, const double low);
   void     SetUpEngulfing(const int barIndex);
   void     SetDownEngulfing(const int barIndex);
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
 * Fix the calculated period
 * 
 * @param  ratesTotal: The number of bars on the chart
 * @param  time: Array with timeseries
 */
void CZigZagBuffers::FixCalcTime(const int ratesTotal, const datetime &time[])
{
   firstBarIndex = ratesTotal - 1;
   firstBarTime = time[firstBarIndex];
   lastBarTime = time[1];
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

/**
 * Clears the buffer and variables
 */
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

/**
 * The latest ZigZag UP direction?
 * @return ( bool )
 */
bool CZigZagBuffers::IsLastTrendUp(void)
{
   return (lastTrend == ZZM_TREND_DIRECTION_UP);
}

/**
 * The latest ZigZag DOWN direction?
 * @return ( bool )
 */
bool CZigZagBuffers::IsLastTrendDown(void)
{
   return (lastTrend == ZZM_TREND_DIRECTION_DOWN);
}

/**
 * Last price UP
 * @return ( double )
 */
double CZigZagBuffers::GetLastUp(void)
{
   return bufferUp[pointBarUp];
}

/**
 * Last price DOWN
 * @return ( double )
 */
double CZigZagBuffers::GetLastDown(void)
{
   return bufferDown[pointBarDown];
}

/**
 * Sets the ZigZag UP value
 * 
 * @param  barIndex: Bar index
 * @param  high: Price "High" bar
 */
void CZigZagBuffers::SetUp(const int barIndex, const double high)
{
   if (lastTrend == ZZM_TREND_DIRECTION_UP)
      bufferUp[pointBarUp] = ZZM_BUFFER_EMPTY;
   lastTrend = ZZM_TREND_DIRECTION_UP;
   pointBarUp = pointBarLast = barIndex;
   bufferUp[barIndex] = bufferMaxChangePoints[barIndex] = high;
   bufferDown[barIndex] = ZZM_BUFFER_EMPTY;
   bufferTrend[barIndex] = ZZM_BUFFER_TREND_UP;
}

/**
 * Sets the ZigZag DOWN value
 * 
 * @param  barIndex: Bar index
 * @param  low: Price "Low" bar
 */
void CZigZagBuffers::SetDown(const int barIndex, const double low)
{
   if (lastTrend == ZZM_TREND_DIRECTION_DOWN)
      bufferDown[pointBarDown] = ZZM_BUFFER_EMPTY;
   lastTrend = ZZM_TREND_DIRECTION_DOWN;
   pointBarDown = pointBarLast = barIndex;
   bufferUp[barIndex] = ZZM_BUFFER_EMPTY;
   bufferDown[barIndex] = bufferMaxChangePoints[barIndex] = low;
   bufferTrend[barIndex] = ZZM_BUFFER_TREND_DOWN;
}

/**
 * Sets the ZigZag UP->DOWN values
 * 
 * @param  barIndex: Bar index
 * @param  high: Price "High" bar
 * @param  low: Price "Low" bar
 */
void CZigZagBuffers::SetUpDown(const int barIndex, const double high, const double low)
{
   if (lastTrend == ZZM_TREND_DIRECTION_UP)
      bufferUp[pointBarUp] = ZZM_BUFFER_EMPTY;
   lastTrend = ZZM_TREND_DIRECTION_DOWN;
   pointBarUp = pointBarDown = pointBarLast = barIndex;
   bufferUp[barIndex] = high;
   bufferDown[barIndex] = bufferMaxChangePoints[barIndex] = low;
   bufferTrend[barIndex] = ZZM_BUFFER_TREND_UP_DOWN;
}

/**
 * Sets the ZigZag DOWN->UP values
 * 
 * @param  barIndex: Bar index
 * @param  high: Price "High" bar
 * @param  low: Price "Low" bar
 */
void CZigZagBuffers::SetDownUp(const int barIndex, const double high, const double low)
{
   if (lastTrend == ZZM_TREND_DIRECTION_DOWN)
      bufferDown[pointBarDown] = ZZM_BUFFER_EMPTY;
   lastTrend = ZZM_TREND_DIRECTION_UP;
   pointBarUp = pointBarDown = pointBarLast = barIndex;
   bufferUp[barIndex] = bufferMaxChangePoints[barIndex] = high;
   bufferDown[barIndex] = low;
   bufferTrend[barIndex] = ZZM_BUFFER_TREND_DOWN_UP;
}

/**
 * Sets the ZigZag UpEngulfing value
 * 
 * @param  barIndex: Bar index
 */
void CZigZagBuffers::SetUpEngulfing(const int barIndex)
{
   bufferUp[barIndex] = bufferDown[barIndex] = bufferMaxChangePoints[barIndex] = ZZM_BUFFER_EMPTY;
   bufferTrend[barIndex] = ZZM_BUFFER_TREND_UP_ENGULFING;
}

/**
 * Sets the ZigZag DownEngulfing value
 * 
 * @param  barIndex: Bar index
 */
void CZigZagBuffers::SetDownEngulfing(const int barIndex)
{
   bufferUp[barIndex] = bufferDown[barIndex] = bufferMaxChangePoints[barIndex] = ZZM_BUFFER_EMPTY;
   bufferTrend[barIndex] = ZZM_BUFFER_TREND_DOWN_ENGULFING;
}
