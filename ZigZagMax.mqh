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

//--- includes
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
   bool isInitialize = prevCalculated < 2 || ZigZagBuffers.IsInitialize(time, limit);
   if (isInitialize)
   {
      limit = ratesTotal - 1;
      g_errorBarsCnt = 0;
      ZigZagBuffers.Clear();

      if (open[limit] > close[limit])
         ZigZagBuffers.SetDown(limit, low[limit]);
      else
         ZigZagBuffers.SetUp(limit, high[limit]);
      
      limit--;
   }
   else
      ZigZagBuffers.UpdatePointBars(limit);
   
   //--- calculate
   for (int i = limit; i > 0 && ! IsStopped(); i--)
   {
      // a pass, the bar has already been processed
      if (time[i] >= ZigZagBuffers.firstBarTime && time[i] <= ZigZagBuffers.lastBarTime)
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
               case ZZM_TREND_DIRECTION_UP:
                  ZigZagUpDown(i, high[i], low[i]);
                  break;
               case ZZM_TREND_DIRECTION_DOWN:
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
         if (ZigZagBuffers.IsLastTrendUp())
            ZigZagBuffers.SetUpEngulfing(i);
         else
            ZigZagBuffers.SetDownEngulfing(i);
      }
   }

   ZigZagBuffers.FixCalcTime(ratesTotal, time);
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

//+------------------------------------------------------------------+
//| ZigZag UP                                                        |
//+------------------------------------------------------------------+
void ZigZagUp(int i, double high, double low)
{
   switch (i_ZzmCalcType)
   {
      case ZZM_CALC_MAIN_DIRECTIONS:
      case ZZM_CALC_BREAKOUTS:
         if (ZigZagBuffers.IsLastTrendUp() && ZigZagBuffers.GetLastUp() > high)
         {
            ZigZagBuffers.SetUpEngulfing(i);
            return;
         }
         break;
   }

   ZigZagBuffers.SetUp(i, high);
}

//+------------------------------------------------------------------+
//| ZigZag DOWN                                                      |
//+------------------------------------------------------------------+
void ZigZagDown(int i, double high, double low)
{
   switch (i_ZzmCalcType)
   {
      case ZZM_CALC_MAIN_DIRECTIONS:
      case ZZM_CALC_BREAKOUTS:
         if (ZigZagBuffers.IsLastTrendDown() && ZigZagBuffers.GetLastDown() < low)
         {
            ZigZagBuffers.SetDownEngulfing(i);
            return;
         }
         break;
   }

   ZigZagBuffers.SetDown(i, low);
}

//+------------------------------------------------------------------+
//| ZigZag UP_DOWN                                                   |
//+------------------------------------------------------------------+
void ZigZagUpDown(int i, double high, double low)
{
   switch (i_ZzmCalcType)
   {
      case ZZM_CALC_MAIN_DIRECTIONS:
         if (ZigZagBuffers.GetLastUp() < high + DOUBLE_MIN_STEP ||
             (ZigZagBuffers.IsLastTrendDown() && ZigZagBuffers.pointBarDown > i+1 && iHigh(NULL, 0, ZigZagBuffers.pointBarDown) < high))
         { break; }
         if (ZigZagBuffers.GetLastDown() < low)
            ZigZagBuffers.SetDownEngulfing(i);
         else
            ZigZagBuffers.SetDown(i, low);
         return;
      case ZZM_CALC_BREAKOUTS:
         if (ZigZagBuffers.IsLastTrendUp() && ZigZagBuffers.GetLastUp() > high)
         {
            ZigZagBuffers.SetDown(i, low);
            return;
         }
         break;
   }
   
   ZigZagBuffers.SetUpDown(i, high, low);
}

//+------------------------------------------------------------------+
//| ZigZag DOWN_UP                                                   |
//+------------------------------------------------------------------+
void ZigZagDownUp(int i, double high, double low)
{
   switch (i_ZzmCalcType)
   {
      case ZZM_CALC_MAIN_DIRECTIONS:
         if (ZigZagBuffers.GetLastDown() > low - DOUBLE_MIN_STEP ||
             (ZigZagBuffers.IsLastTrendUp() && ZigZagBuffers.pointBarUp > i+1 && iLow(NULL, 0, ZigZagBuffers.pointBarUp) > low))
         { break; }
         if (ZigZagBuffers.GetLastUp() > high)
            ZigZagBuffers.SetUpEngulfing(i);
         else
            ZigZagBuffers.SetUp(i, high);
         return;
      case ZZM_CALC_BREAKOUTS:
         if (ZigZagBuffers.IsLastTrendDown() && ZigZagBuffers.GetLastDown() < low)
         {
            ZigZagBuffers.SetUp(i, high);
            return;
         }
         break;
   }

   ZigZagBuffers.SetDownUp(i, high, low);
}

//+------------------------------------------------------------------+
//| The breakdown side of the previous bar                           |
//+------------------------------------------------------------------+
int PrevBarBreakSide(const datetime time, const double prevBarHigh, const double prevBarLow)
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
                  return ZZM_TREND_DIRECTION_UP;
            }
            else if (prevBarLow > rates[i].low)
               return ZZM_TREND_DIRECTION_DOWN;
         }
         if (i >= ratesCnt)
            return 0;  // TREND_NONE
      }
      else
         return -1;  // TREND_ERROR
   }

   // search in ticks
   if (! i_IsUseTickHistory)
      return 0;  // TREND_NONE
   
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
         return -1;  // TREND_ERROR

      for (int i = 0; i < ticksCnt && ! IsStopped(); i++)
      {
         if ((ticks[i].flags & TICK_FLAG_BID) != TICK_FLAG_BID || ticks[i].bid < _Point)
            continue;
         if (prevBarHigh < ticks[i].bid)
            return ZZM_TREND_DIRECTION_UP;
         else if (prevBarLow > ticks[i].bid)
            return ZZM_TREND_DIRECTION_DOWN;
         if (ticks[i].time_msc >= timeMsEnd)
            return 0;  // TREND_NONE
      }
      timeMs = ticks[ticksCnt - 1].time_msc + 1;
   } while (! IsStopped());
   
   return 0;  // TREND_NONE
}

//+------------------------------------------------------------------+
