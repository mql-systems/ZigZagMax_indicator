//###<Indicators/AT/ZigZagMax/ZigZagMax.mq5>
//+------------------------------------------------------------------+
//|                                                    ZigZagMax.mq4 |
//|                       Copyright 2022-2024, Diamond Systems Corp. |
//|               https://github.com/mql-systems/ZigZagMax_indicator |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022-2024, Diamond Systems Corp."
#property link      "https://github.com/mql-systems/ZigZagMax_indicator"
#property strict

//--- defines
#define DOUBLE_MIN_STEP                   0.00000001

#include "ZigZagBuffers.mqh"

//--- ENUMs
enum ENUM_ZZM_CALC_TYPE
{
   ZZM_CALC_MAIN_DIRECTIONS,  // Main directions
   ZZM_CALC_ENGULFING_BARS,   // Engulfing bars
   ZZM_CALC_BREAKOUTS,        // Breakouts
};

//--- inputs
input bool                 i_IsUseTickHistory = false;                  // Use tick history
input ENUM_ZZM_CALC_TYPE   i_ZzmCalcType = ZZM_CALC_MAIN_DIRECTIONS;    // ZigZag type (filter)

//--- global variables
int      g_errorBarsCnt;
string   g_globalVarName_ErrorBarsCnt;
//---
CZigZagBuffers ZigZagBuffers;

//+------------------------------------------------------------------+
//| App initialization function                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   SetIndexBuffer(0, ZigZagBuffers.bufferUp);
   SetIndexBuffer(1, ZigZagBuffers.bufferDown);
   SetIndexBuffer(2, ZigZagBuffers.bufferMaxChangePoints);
   SetIndexBuffer(3, ZigZagBuffers.bufferTrend, INDICATOR_CALCULATIONS);

#ifdef __MQL4__
   SetIndexEmptyValue(0, ZZM_BUFFER_EMPTY);
   SetIndexEmptyValue(1, ZZM_BUFFER_EMPTY);
   SetIndexEmptyValue(2, ZZM_BUFFER_EMPTY);
   SetIndexEmptyValue(3, ZZM_BUFFER_EMPTY);
#else
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, ZZM_BUFFER_EMPTY);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, ZZM_BUFFER_EMPTY);
#endif

   ZigZagBuffers.Clear();

   //--- global variables
   g_errorBarsCnt = 0;
   g_globalVarName_ErrorBarsCnt = "ZZM_" + _Symbol + "_" + IntegerToString(PeriodSeconds()) + "_ErrorBarsCnt";

   GlobalVariableSet(g_globalVarName_ErrorBarsCnt, 0.0);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_errorBarsCnt = 0;
   ZigZagBuffers.Clear();

   Comment("");
   GlobalVariableDel(g_globalVarName_ErrorBarsCnt);
}

//+------------------------------------------------------------------+
//| Indicator iteration function                                     |
//+------------------------------------------------------------------+
int OnCalculate(const int ratesTotal,
                const int prevCalculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tickVolume[],
                const long &volume[],
                const int &spread[])
{
   //--- new bar
   if (ratesTotal - prevCalculated <= 0)
      return ratesTotal;
   if (ratesTotal < 5 || prevCalculated < 0)
      return 0;
   int limit = ratesTotal - prevCalculated;
   
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);

   //--- first start indicator (initialize)
   if (prevCalculated < 2 || ZigZagBuffers.IsInitialize(time, limit))
   {
      g_errorBarsCnt = 0;
      ZigZagBuffers.Clear();

      limit = ratesTotal - 1;

      if (open[limit] > close[limit])
      {
         ZigZagBuffers.bufferUp[limit] = ZZM_BUFFER_EMPTY;
         ZigZagBuffers.bufferDown[limit] = low[limit];
         ZigZagBuffers.bufferMaxChangePoints[limit] = low[limit];
         ZigZagBuffers.bufferTrend[limit] = ZZM_BUFFER_TREND_DOWN;

         g_prevCalcInfo.ZigZagLastDown(limit);
      }
      else
      {
         ZigZagBuffers.bufferUp[limit] = high[limit];
         ZigZagBuffers.bufferDown[limit] = ZZM_BUFFER_EMPTY;
         ZigZagBuffers.bufferMaxChangePoints[limit] = high[limit];
         ZigZagBuffers.bufferTrend[limit] = ZZM_BUFFER_TREND_UP;

         g_prevCalcInfo.ZigZagLastDown(limit);
      }
      limit--;
   }
   else
      ZigZagBuffers.UpdatePointBars(limit);
   
   //--- calculate
   for (int i = limit; i > 0 && ! IsStopped(); i--)
   {
      // a pass, the bar has already been processed
      if (time[i] >= g_prevCalcInfo.firstBarTime && time[i] <= g_prevCalcInfo.lastBarTime)
         continue;
      
      // calc bar
      if (limit > 100)
         Comment("Load: ", DoubleToString(100 - (i / (limit * 1.0)) * 100, 2), "%");

      if (high[i+1] < high[i] + DOUBLE_MIN_STEP)
      {
         if (low[i+1] < low[i] + DOUBLE_MIN_STEP)
            ZigZagUp(i, high[i], low[i]);
         else
         {
            switch (PrevBarBreakSide(time[i], high[i+1], low[i+1]))
            {
               case ZZM_TREND_UP:
                  ZigZagUpDown(i, high[i], low[i]);
                  break;
               case ZZM_TREND_DOWN:
                  ZigZagDownUp(i, high[i], low[i]);
                  break;
               default:
                  if (i_IsUseTickHistory)
                     g_errorBarsCnt++;
                  // The rest of the case: you should not hope for this calculation, since it considers open and close prices.
                  if (open[i] > close[i])
                     ZigZagUpDown(i, high[i], low[i]);
                  else
                     ZigZagDownUp(i, high[i], low[i]);
            }
         }
      }
      else if (low[i+1] > low[i] - DOUBLE_MIN_STEP)
         ZigZagDown(i, high[i], low[i]);
      else if (i_ZzmCalcType == ZZM_CALC_ENGULFING_BARS)
      {
         if (ZigZagBuffers.bufferMaxChangePoints[i+1] > high[i])
            ZigZagDown(i, high[i], low[i]);
         else
            ZigZagUp(i, high[i], low[i]);
      }
      else
      {
         if (ZigZagBuffers.bufferUp[g_prevZigZagPointBar] != ZZM_BUFFER_EMPTY)
            ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_UP_ENGULFING;
         else
            ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_DOWN_ENGULFING;
         
         ZigZagBuffers.bufferUp[i] = ZZM_BUFFER_EMPTY;
         ZigZagBuffers.bufferDown[i] = ZZM_BUFFER_EMPTY;
         ZigZagBuffers.bufferMaxChangePoints[i] = ZZM_BUFFER_EMPTY;
      }
   }

   g_prevCalcInfo.firstBarIndex = ratesTotal - 1;
   g_prevCalcInfo.firstBarTime = time[g_prevCalcInfo.firstBarIndex];
   g_prevCalcInfo.lastBarTime = time[1];

   Comment("");

   //--- calc accuracy
   if (i_IsUseTickHistory)
   {
      GlobalVariableSet(g_globalVarName_ErrorBarsCnt, g_errorBarsCnt);
      if (g_errorBarsCnt > 0 && isInitialize)
         Print("Accuracy: ", DoubleToString(100 - (g_errorBarsCnt / (ratesTotal * 1.0)) * 100, 2));
   }

   return ratesTotal;
}

/**
 * Delete the previous ZigZag point
 * 
 * @param  trend: ENUM_ZZM_TREND
 * @return ( bool )
 */
bool DeletePrevZigZagPoint(ENUM_ZZM_TREND trend)
{
   switch (trend)
   {
      case ZZM_TREND_UP:
         if (IsPrevZigZagTrendUp())
         {
            ZigZagBuffers.bufferUp[g_prevZigZagPointBar] = ZZM_BUFFER_EMPTY;
            return true;
         }
         break;
      case ZZM_TREND_DOWN:
         if (IsPrevZigZagTrendDown())
         {
            ZigZagBuffers.bufferDown[g_prevZigZagPointBar] = ZZM_BUFFER_EMPTY;
            return true;
         }
         break;
   }

   return false;
}

/**
 * Has the last zigzag trend ended "UP"?
 * @return ( bool )
 */
bool IsPrevZigZagTrendUp()
{
   return (NormalizeDouble(ZigZagBuffers.bufferTrend[g_prevZigZagPointBar] - (ZZM_BUFFER_TREND_UP), 8) == 0 ||
           NormalizeDouble(ZigZagBuffers.bufferTrend[g_prevZigZagPointBar] - (ZZM_BUFFER_TREND_DOWN_UP), 8) == 0);
}

/**
 * Has the last zigzag trend ended "DOWN"?
 * @return ( bool )
 */
bool IsPrevZigZagTrendDown()
{
   return (NormalizeDouble(ZigZagBuffers.bufferTrend[g_prevZigZagPointBar] - (ZZM_BUFFER_TREND_DOWN), 8) == 0 ||
           NormalizeDouble(ZigZagBuffers.bufferTrend[g_prevZigZagPointBar] - (ZZM_BUFFER_TREND_UP_DOWN), 8) == 0);
}

//+------------------------------------------------------------------+
//| ZigZag UP                                                        |
//+------------------------------------------------------------------+
void ZigZagUp(int i, double high, double low)
{
   ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_EMPTY;

   switch (i_ZzmCalcType)
   {
      case ZZM_CALC_MAIN_DIRECTIONS:
         if (IsPrevZigZagTrendUp() && ZigZagBuffers.bufferUp[g_prevZigZagPointBar] > high)
         {
            ZigZagBuffers.bufferUp[i] = ZZM_BUFFER_EMPTY;
            ZigZagBuffers.bufferDown[i] = ZZM_BUFFER_EMPTY;
            ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_UP_ENGULFING;
            ZigZagBuffers.bufferMaxChangePoints[i] = ZZM_BUFFER_EMPTY;
            return;
         }
         break;
      case ZZM_CALC_BREAKOUTS:
         if (ZigZagBuffers.bufferMaxChangePoints[i+1] == ZZM_BUFFER_EMPTY && ZigZagBuffers.bufferUp[g_prevZigZagPointBar] != ZZM_BUFFER_EMPTY)
         {
            ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_DOWN_UP;
            ZigZagBuffers.bufferDown[i] = low;
            g_prevCalcInfo.ZigZagLastDown(i);
         }
         break;
   }
   
   if (ZigZagBuffers.bufferTrend[i] == ZZM_BUFFER_EMPTY)
   {
      DeletePrevZigZagPoint(ZZM_TREND_UP);
      ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_UP;
      ZigZagBuffers.bufferDown[i] = ZZM_BUFFER_EMPTY;
   }

   g_prevCalcInfo.ZigZagLastUp(i);
   ZigZagBuffers.bufferUp[i] = high;
   ZigZagBuffers.bufferMaxChangePoints[i] = high;
}

//+------------------------------------------------------------------+
//| ZigZag DOWN                                                      |
//+------------------------------------------------------------------+
void ZigZagDown(int i, double high, double low)
{
   ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_EMPTY;

   switch (i_ZzmCalcType)
   {
      case ZZM_CALC_MAIN_DIRECTIONS:
         if (IsPrevZigZagTrendDown() && ZigZagBuffers.bufferDown[g_prevZigZagPointBar] < low)
         {
            ZigZagBuffers.bufferUp[i] = ZZM_BUFFER_EMPTY;
            ZigZagBuffers.bufferDown[i] = ZZM_BUFFER_EMPTY;
            ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_DOWN_ENGULFING;
            ZigZagBuffers.bufferMaxChangePoints[i] = ZZM_BUFFER_EMPTY;
            return;
         }
         break;
      case ZZM_CALC_BREAKOUTS:
         if (ZigZagBuffers.bufferMaxChangePoints[i+1] == ZZM_BUFFER_EMPTY && ZigZagBuffers.bufferDown[g_prevZigZagPointBar] != ZZM_BUFFER_EMPTY)
         {
            ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_UP_DOWN;
            ZigZagBuffers.bufferUp[i] = high;
            g_prevCalcInfo.ZigZagLastUp(i);
         }
         break;
   }

   if (ZigZagBuffers.bufferTrend[i] == ZZM_BUFFER_EMPTY)
   {
      DeletePrevZigZagPoint(ZZM_TREND_DOWN);
      ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_DOWN;
      ZigZagBuffers.bufferUp[i] = ZZM_BUFFER_EMPTY;
   }

   g_prevCalcInfo.ZigZagLastDown(i);
   ZigZagBuffers.bufferDown[i] = low;
   ZigZagBuffers.bufferMaxChangePoints[i] = low;
}

//+------------------------------------------------------------------+
//| ZigZag UP_DOWN                                                   |
//+------------------------------------------------------------------+
void ZigZagUpDown(int i, double high, double low)
{
   ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_EMPTY;

   switch (i_ZzmCalcType)
   {
      case ZZM_CALC_MAIN_DIRECTIONS:
         if (IsPrevZigZagTrendDown())
         {
            if (ZigZagBuffers.bufferDown[g_prevZigZagPointBar] < low)
            {
               ZigZagBuffers.bufferUp[i] = ZZM_BUFFER_EMPTY;
               ZigZagBuffers.bufferDown[i] = ZZM_BUFFER_EMPTY;
               ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_DOWN_ENGULFING;
               ZigZagBuffers.bufferMaxChangePoints[i] = ZZM_BUFFER_EMPTY;
               return;
            }
            else
            {
               DeletePrevZigZagPoint(ZZM_TREND_DOWN);
               ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_DOWN;
               ZigZagBuffers.bufferUp[i] = ZZM_BUFFER_EMPTY;
            }
         }
         else if (ZigZagBuffers.bufferUp[g_prevZigZagPointBar] > high)
         {
            ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_DOWN;
            ZigZagBuffers.bufferUp[i] = ZZM_BUFFER_EMPTY;
         }
         break;
      case ZZM_CALC_BREAKOUTS:
         if (ZigZagBuffers.bufferMaxChangePoints[i+1] == ZZM_BUFFER_EMPTY && ZigZagBuffers.bufferUp[g_prevZigZagPointBar] != ZZM_BUFFER_EMPTY && ZigZagBuffers.bufferUp[g_prevZigZagPointBar] > high + DOUBLE_MIN_STEP)
         {
            ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_DOWN;
            ZigZagBuffers.bufferUp[i] = ZZM_BUFFER_EMPTY;
         }
         break;
   }
   
   if (ZigZagBuffers.bufferTrend[i] == ZZM_BUFFER_EMPTY)
   {
      DeletePrevZigZagPoint(ZZM_TREND_UP);
      ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_UP_DOWN;
      ZigZagBuffers.bufferUp[i] = high;
      g_prevCalcInfo.ZigZagLastUp(i);
   }
   
   g_prevCalcInfo.ZigZagLastDown(i);
   ZigZagBuffers.bufferMaxChangePoints[i] = low;
   ZigZagBuffers.bufferDown[i] = low;
}

//+------------------------------------------------------------------+
//| ZigZag DOWN_UP                                                   |
//+------------------------------------------------------------------+
void ZigZagDownUp(int i, double high, double low)
{
   ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_EMPTY;

   switch (i_ZzmCalcType)
   {
      case ZZM_CALC_MAIN_DIRECTIONS:
         if (IsPrevZigZagTrendUp())
         {
            if (ZigZagBuffers.bufferUp[g_prevZigZagPointBar] > high)
            {
               ZigZagBuffers.bufferUp[i] = ZZM_BUFFER_EMPTY;
               ZigZagBuffers.bufferDown[i] = ZZM_BUFFER_EMPTY;
               ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_UP_ENGULFING;
               ZigZagBuffers.bufferMaxChangePoints[i] = ZZM_BUFFER_EMPTY;
               return;
            }
            else
            {
               DeletePrevZigZagPoint(ZZM_TREND_UP);
               ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_UP;
               ZigZagBuffers.bufferUp[i] = ZZM_BUFFER_EMPTY;
            }
         }
         else if (ZigZagBuffers.bufferDown[g_prevZigZagPointBar] < low)
         {
            ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_UP;
            ZigZagBuffers.bufferUp[i] = ZZM_BUFFER_EMPTY;
         }
         break;
      case ZZM_CALC_BREAKOUTS:
         if (ZigZagBuffers.bufferMaxChangePoints[i+1] == ZZM_BUFFER_EMPTY && ZigZagBuffers.bufferDown[g_prevZigZagPointBar] != ZZM_BUFFER_EMPTY && ZigZagBuffers.bufferDown[g_prevZigZagPointBar] < low - DOUBLE_MIN_STEP)
         {
            ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_UP;
            ZigZagBuffers.bufferDown[i] = ZZM_BUFFER_EMPTY;
         }
         break;
   }

   if (ZigZagBuffers.bufferTrend[i] == ZZM_BUFFER_EMPTY)
   {
      DeletePrevZigZagPoint(ZZM_TREND_DOWN);
      ZigZagBuffers.bufferTrend[i] = ZZM_BUFFER_TREND_DOWN_UP;
      ZigZagBuffers.bufferDown[i] = low;
      g_prevCalcInfo.ZigZagLastDown(i);
   }
   
   g_prevCalcInfo.ZigZagLastUp(i);
   ZigZagBuffers.bufferMaxChangePoints[i] = high;
   ZigZagBuffers.bufferUp[i] = high;
}

//+------------------------------------------------------------------+
//| The breakdown side of the previous bar                           |
//+------------------------------------------------------------------+
ENUM_ZZM_TREND PrevBarBreakSide(const datetime time, const double prevBarHigh, const double prevBarLow)
{
   long timeMs = time * 1000;

   // search in M1
   if (Period() != PERIOD_M1)
   {
      int ratesCnt = 0;
      MqlRates rates[];
      for (int i = 0; i < 3; i++)
      {
         ratesCnt = CopyRates(_Symbol, PERIOD_M1, time, time + PeriodSeconds() - 1, rates);
         if (ratesCnt > 0)
            break;
      }
      if (ratesCnt > 0)
      {
         int i = 0;
         for (; i < ratesCnt && ! IsStopped(); i++)
         {
            if (prevBarHigh < rates[i].high)
            {
               if (prevBarLow > rates[i].low)
               {
                  timeMs = rates[i].time * 1000;
                  break;  // search in ticks
               }
               else
                  return ZZM_TREND_UP;
            }
            else if (prevBarLow > rates[i].low)
               return ZZM_TREND_DOWN;
         }
         if (i >= ratesCnt)
            return ZZM_TREND_NONE;
      }
      else
         return ZZM_TREND_ERROR;
   }

   // search in ticks
   if (! i_IsUseTickHistory)
      return ZZM_TREND_NONE;
   
   long timeMsEnd = timeMs + 60000;
   do
   {
      MqlTick ticks[];
      int ticksCnt = 0;
      for (int i = 0; i < 3; i++)
      {
         ticksCnt = CopyTicks(_Symbol, ticks, COPY_TICKS_ALL, timeMs, 50);
         if (ticksCnt > 0)
            break;
      }
      if (ticksCnt < 1)
         return ZZM_TREND_ERROR;

      for (int i = 0; i < ticksCnt && ! IsStopped(); i++)
      {
         if ((ticks[i].flags & TICK_FLAG_BID) != TICK_FLAG_BID || ticks[i].bid < _Point)
            continue;
         if (prevBarHigh < ticks[i].bid)
            return ZZM_TREND_UP;
         else if (prevBarLow > ticks[i].bid)
            return ZZM_TREND_DOWN;
         if (ticks[i].time_msc >= timeMsEnd)
            return ZZM_TREND_NONE;
      }
      timeMs = ticks[ticksCnt - 1].time_msc + 1;
   } while (! IsStopped());
   
   return ZZM_TREND_NONE;
}

//+------------------------------------------------------------------+
