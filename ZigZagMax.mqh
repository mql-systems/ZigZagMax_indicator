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

#define ZZM_BUFFER_EMPTY                  0.0
#define ZZM_BUFFER_TREND_UP               1.0
#define ZZM_BUFFER_TREND_UP_DOWN          2.0
#define ZZM_BUFFER_TREND_UP_ENGULFING     3.0
#define ZZM_BUFFER_TREND_DOWN            -1.0
#define ZZM_BUFFER_TREND_DOWN_UP         -2.0
#define ZZM_BUFFER_TREND_DOWN_ENGULFING  -3.0

//--- inputs
input bool i_IsUseTickHistory = false;    // Use tick history
input bool i_IsEngulfingPoints = true;    // Engulfing points

//--- ENUMs
enum ENUM_ZZM_TREND
{
   ZZM_TREND_ERROR = -1,
   ZZM_TREND_NONE,
   ZZM_TREND_UP,
   ZZM_TREND_DOWN,
   ZZM_TREND_UP_DOWN,
   ZZM_TREND_DOWN_UP,
};

//--- structs
struct PrevCalcDataInfo
{
   int      firstBarIndex;
   datetime firstBarTime;
   datetime lastBarTime;
};

//--- global variables
int      g_prevZigZagPointBar;
int      g_errorBarsCnt;
string   g_globalVarName_ErrorBarsCnt;

//--- buffers
double g_bufferUp[];
double g_bufferDown[];
double g_bufferMaxChangePoints[];
double g_bufferTrend[];
//---
PrevCalcDataInfo g_prevCalcDataInfo;

//+------------------------------------------------------------------+
//| App initialization function                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   SetIndexBuffer(0, g_bufferUp);
   SetIndexBuffer(1, g_bufferDown);
   SetIndexBuffer(2, g_bufferMaxChangePoints);
   SetIndexBuffer(3, g_bufferTrend, INDICATOR_CALCULATIONS);

#ifdef __MQL4__
   SetIndexEmptyValue(0, ZZM_BUFFER_EMPTY);
   SetIndexEmptyValue(1, ZZM_BUFFER_EMPTY);
   SetIndexEmptyValue(2, ZZM_BUFFER_EMPTY);
   SetIndexEmptyValue(3, ZZM_BUFFER_EMPTY);
#else
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, ZZM_BUFFER_EMPTY);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, ZZM_BUFFER_EMPTY);
#endif

   BufferInitialize();

   //--- global variables
   g_globalVarName_ErrorBarsCnt = "ZZM_" + _Symbol + "_" + IntegerToString(PeriodSeconds()) + "_ErrorBarsCnt";

   GlobalVariableSet(g_globalVarName_ErrorBarsCnt, 0.0);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_prevZigZagPointBar = 0;
   g_errorBarsCnt = 0;
   g_prevCalcDataInfo.firstBarIndex = 0;
   g_prevCalcDataInfo.firstBarTime = 0;
   g_prevCalcDataInfo.lastBarTime = 0;

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
   bool isInitialize = prevCalculated < 2;
   if (! isInitialize)
   {
      if (time[1] != g_prevCalcDataInfo.lastBarTime)
      {
         if (time[limit + 1] != g_prevCalcDataInfo.lastBarTime)
            isInitialize = true;
      }
      else if (time[g_prevCalcDataInfo.firstBarIndex] != g_prevCalcDataInfo.firstBarTime)
         return true;
   }

   if (isInitialize)
   {
      BufferInitialize();

      limit = ratesTotal - 1;

      if (open[limit] > close[limit])
      {
         g_bufferUp[limit] = ZZM_BUFFER_EMPTY;
         g_bufferDown[limit] = low[limit];
         g_bufferMaxChangePoints[limit] = low[limit];
         g_bufferTrend[limit] = ZZM_BUFFER_TREND_DOWN;
      }
      else
      {
         g_bufferUp[limit] = high[limit];
         g_bufferDown[limit] = ZZM_BUFFER_EMPTY;
         g_bufferMaxChangePoints[limit] = high[limit];
         g_bufferTrend[limit] = ZZM_BUFFER_TREND_UP;
      }

      g_prevZigZagPointBar = limit;
      limit--;
   }
   else
      g_prevZigZagPointBar += limit;
   
   //--- calculate
   for (int i = limit; i > 0 && ! IsStopped(); i--)
   {
      // a pass, the bar has already been processed
      if (time[i] >= g_prevCalcDataInfo.firstBarTime && time[i] <= g_prevCalcDataInfo.lastBarTime)
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
      else if (i_IsEngulfingPoints)
      {
         if (g_bufferMaxChangePoints[i+1] > high[i])
            ZigZagDown(i, high[i], low[i]);
         else
            ZigZagUp(i, high[i], low[i]);
      }
      else
      {
         if (g_bufferUp[g_prevZigZagPointBar] != ZZM_BUFFER_EMPTY)
            g_bufferTrend[i] = ZZM_BUFFER_TREND_UP_ENGULFING;
         else
            g_bufferTrend[i] = ZZM_BUFFER_TREND_DOWN_ENGULFING;
         
         g_bufferMaxChangePoints[i] = ZZM_BUFFER_EMPTY;
         g_bufferUp[i] = ZZM_BUFFER_EMPTY;
         g_bufferDown[i] = ZZM_BUFFER_EMPTY;
      }
   }

   g_prevCalcDataInfo.firstBarIndex = ratesTotal - 1;
   g_prevCalcDataInfo.firstBarTime = time[g_prevCalcDataInfo.firstBarIndex];
   g_prevCalcDataInfo.lastBarTime = time[1];

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
//| Delete the previous ZigZag point                                 |
//+------------------------------------------------------------------+
void DeletePrevZigZagPoint(ENUM_ZZM_TREND trend)
{
   switch (trend)
   {
      case ZZM_TREND_UP:
         if (NormalizeDouble(g_bufferTrend[g_prevZigZagPointBar] - (ZZM_BUFFER_TREND_UP), 8) == 0 ||
             NormalizeDouble(g_bufferTrend[g_prevZigZagPointBar] - (ZZM_BUFFER_TREND_DOWN_UP), 8) == 0)
         {
            g_bufferUp[g_prevZigZagPointBar] = ZZM_BUFFER_EMPTY;
         }
         return;
      case ZZM_TREND_DOWN:
         if (NormalizeDouble(g_bufferTrend[g_prevZigZagPointBar] - (ZZM_BUFFER_TREND_DOWN), 8) == 0 ||
             NormalizeDouble(g_bufferTrend[g_prevZigZagPointBar] - (ZZM_BUFFER_TREND_UP_DOWN), 8) == 0)
         {
            g_bufferDown[g_prevZigZagPointBar] = ZZM_BUFFER_EMPTY;
         }
         return;
   }
}

//+------------------------------------------------------------------+
//| ZigZag UP                                                        |
//+------------------------------------------------------------------+
void ZigZagUp(int i, double high, double low)
{
   if (! i_IsEngulfingPoints && g_bufferMaxChangePoints[i+1] == ZZM_BUFFER_EMPTY && g_bufferUp[g_prevZigZagPointBar] != ZZM_BUFFER_EMPTY)
   {
      g_bufferTrend[i] = ZZM_BUFFER_TREND_DOWN_UP;
      g_bufferDown[i] = low;
   }
   else
   {
      DeletePrevZigZagPoint(ZZM_TREND_UP);
      g_bufferTrend[i] = ZZM_BUFFER_TREND_UP;
      g_bufferDown[i] = ZZM_BUFFER_EMPTY;
   }

   g_prevZigZagPointBar = i;
   g_bufferUp[i] = high;
   g_bufferMaxChangePoints[i] = high;
}

//+------------------------------------------------------------------+
//| ZigZag DOWN                                                      |
//+------------------------------------------------------------------+
void ZigZagDown(int i, double high, double low)
{
   if (! i_IsEngulfingPoints && g_bufferMaxChangePoints[i+1] == ZZM_BUFFER_EMPTY && g_bufferDown[g_prevZigZagPointBar] != ZZM_BUFFER_EMPTY)
   {
      g_bufferTrend[i] = ZZM_BUFFER_TREND_UP_DOWN;
      g_bufferUp[i] = high;
   }
   else
   {
      DeletePrevZigZagPoint(ZZM_TREND_DOWN);
      g_bufferTrend[i] = ZZM_BUFFER_TREND_DOWN;
      g_bufferUp[i] = ZZM_BUFFER_EMPTY;
   }

   g_prevZigZagPointBar = i;
   g_bufferDown[i] = low;
   g_bufferMaxChangePoints[i] = low;
}

//+------------------------------------------------------------------+
//| ZigZag UP_DOWN                                                   |
//+------------------------------------------------------------------+
void ZigZagUpDown(int i, double high, double low)
{
   if (! i_IsEngulfingPoints && g_bufferMaxChangePoints[i+1] == ZZM_BUFFER_EMPTY &&
       g_bufferUp[g_prevZigZagPointBar] != ZZM_BUFFER_EMPTY && g_bufferUp[g_prevZigZagPointBar] > high + DOUBLE_MIN_STEP)
   {
      g_bufferTrend[i] = ZZM_BUFFER_TREND_DOWN;
      g_bufferUp[i] = ZZM_BUFFER_EMPTY;
   }
   else
   {
      DeletePrevZigZagPoint(ZZM_TREND_UP);
      g_bufferTrend[i] = ZZM_BUFFER_TREND_UP_DOWN;
      g_bufferUp[i] = high;
   }
   
   g_prevZigZagPointBar = i;
   g_bufferMaxChangePoints[i] = low;
   g_bufferDown[i] = low;
}

//+------------------------------------------------------------------+
//| ZigZag DOWN_UP                                                   |
//+------------------------------------------------------------------+
void ZigZagDownUp(int i, double high, double low)
{
   if (! i_IsEngulfingPoints && g_bufferMaxChangePoints[i+1] == ZZM_BUFFER_EMPTY &&
       g_bufferDown[g_prevZigZagPointBar] != ZZM_BUFFER_EMPTY && g_bufferDown[g_prevZigZagPointBar] < low - DOUBLE_MIN_STEP)
   {
      g_bufferTrend[i] = ZZM_BUFFER_TREND_UP;
      g_bufferDown[i] = ZZM_BUFFER_EMPTY;
   }
   else
   {
      DeletePrevZigZagPoint(ZZM_TREND_DOWN);
      g_bufferTrend[i] = ZZM_BUFFER_TREND_DOWN_UP;
      g_bufferDown[i] = low;
   }
   
   g_prevZigZagPointBar = i;
   g_bufferMaxChangePoints[i] = high;
   g_bufferUp[i] = high;
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
//| Buffer initialize                                                |
//+------------------------------------------------------------------+
void BufferInitialize()
{
   g_errorBarsCnt = 0;

   g_prevCalcDataInfo.firstBarIndex = 0;
   g_prevCalcDataInfo.firstBarTime = 0;
   g_prevCalcDataInfo.lastBarTime = 0;

   ArrayInitialize(g_bufferUp, ZZM_BUFFER_EMPTY);
   ArrayInitialize(g_bufferDown, ZZM_BUFFER_EMPTY);
   ArrayInitialize(g_bufferMaxChangePoints, ZZM_BUFFER_EMPTY);
   ArrayInitialize(g_bufferTrend, ZZM_BUFFER_EMPTY);

   ArraySetAsSeries(g_bufferUp, true);
   ArraySetAsSeries(g_bufferDown, true);
   ArraySetAsSeries(g_bufferMaxChangePoints, true);
   ArraySetAsSeries(g_bufferTrend, true);
}

//+------------------------------------------------------------------+
