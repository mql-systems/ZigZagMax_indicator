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
#define ZZM_BUFFER_EMPTY            0.0
#define ZZM_BUFFER_TREND_UP         1.0
#define ZZM_BUFFER_TREND_UP_DOWN    2.0
#define ZZM_BUFFER_TREND_DOWN      -1.0
#define ZZM_BUFFER_TREND_DOWN_UP   -2.0

//--- ENUMs
enum ZZM_TREND
{
   ZZM_TREND_ERROR = -1,
   ZZM_TREND_NONE,
   ZZM_TREND_UP,
   ZZM_TREND_DOWN,
};

//--- global variables
datetime g_lastBarTime;

datetime g_iHighTime;
datetime g_iLowTime;
datetime g_iSaveTime;
double   g_iHighPrice;
double   g_iLowPrice;
int      g_trendType;
int      g_iSaveBar;
int      g_iSearchBar;

//--- buffers
double g_bufferUp[];
double g_bufferDown[];
double g_bufferMaxChangePoints[];
double g_bufferTrend[];

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

   return INIT_SUCCEEDED;
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
   int limit = ratesTotal - prevCalculated;
   if (limit <= 0)
      return ratesTotal;
   if (ratesTotal < 2 || prevCalculated < 0)
      return 0;
   
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low,  true);
   ArraySetAsSeries(time, true);

   //--- first start indicator (initialize)
   if (prevCalculated == 0)
   {
      BufferInitialize();

      limit--;
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
   }
   else if (time[limit] != g_lastBarTime)
      return 0;
   
   g_lastBarTime = time[1];
   
   //--- calculate
   for (int i = limit - 1; i > 0; i--)
   {
      if (high[i+1] < high[i])
      {
         if (low[i+1] < low[i])
            ChangeZigZagUp(ratesTotal, i, high[i]);
         else
         {
            switch (PrevBarBreakSide(time[i], high[i+1], low[i+1]))
            {
               case ZZM_TREND_UP:
                  ChangeZigZagUp(ratesTotal, i, high[i]);
                  break;
               case ZZM_TREND_DOWN:
                  ChangeZigZagDown(ratesTotal, i, low[i]);
                  break;
               // case ZZM_TREND_NONE AND DEFAULT:
               // You should not hope for this calculation, since it considers open and close prices.
               default:
                  if (open[i] < close[i])
                     ChangeZigZagUp(ratesTotal, i, high[i]);
                  else
                     ChangeZigZagDown(ratesTotal, i, low[i]);
            }
         }
      }
      else if (low[i+1] > low[i])
         ChangeZigZagDown(ratesTotal, i, low[i]);
      // else
      //    Print("TREND_NONE"); // TODO: TREND_NONE
   }

   return ratesTotal;
}

//+------------------------------------------------------------------+
//| The breakdown side of the previous bar                           |
//+------------------------------------------------------------------+
ZZM_TREND PrevBarBreakSide(const datetime time, const double prevBarHigh, const double prevBarLow)
{
   long timeMs = time * 1000;

   // search in M1
   if (Period() != PERIOD_M1)
   {
      MqlRates rates[];
      int ratesCnt = CopyRates(_Symbol, PERIOD_M1, time, time + PeriodSeconds() - 1, rates);
      if (ratesCnt > 0)
      {
         int i = 0;
         for (; i < ratesCnt; i++)
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
   MqlTick ticks[];
   int ticksCnt = CopyTicksRange(_Symbol, ticks, COPY_TICKS_ALL, timeMs, timeMs + 60000);
   if (ticksCnt < 1)
      return ZZM_TREND_ERROR;

   for (int i = 0; i < ticksCnt; i++)
   {
      if ((ticks[i].flags & TICK_FLAG_BID) != TICK_FLAG_BID || ticks[i].bid < _Point)
         continue;
      if (prevBarHigh < ticks[i].bid)
         return ZZM_TREND_UP;
      else if (prevBarLow > ticks[i].bid)
         return ZZM_TREND_DOWN;
   }
   
   return ZZM_TREND_NONE;
}

//+------------------------------------------------------------------+
//| Change ZigZag Up                                                 |
//+------------------------------------------------------------------+
void ChangeZigZagUp(int ratesTotal, int i, double high)
{
   for (int j = i + 1; j < ratesTotal; j++)
   {
      if (g_bufferTrend[j] > 0)
      {
         g_bufferUp[j] = ZZM_BUFFER_EMPTY;
         break;
      }
      else if (g_bufferTrend[j] < 0)
         break;
   }

   g_bufferUp[i] = high;
   g_bufferDown[i] = ZZM_BUFFER_EMPTY;
   g_bufferMaxChangePoints[i] = high;
   g_bufferTrend[i] = ZZM_BUFFER_TREND_UP;
}

//+------------------------------------------------------------------+
//| Change ZigZag Down                                               |
//+------------------------------------------------------------------+
void ChangeZigZagDown(int ratesTotal, int i, double low)
{
   for (int j = i + 1; j < ratesTotal; j++)
   {
      if (g_bufferTrend[j] < 0)
      {
         g_bufferDown[j] = ZZM_BUFFER_EMPTY;
         break;
      }
      else if (g_bufferTrend[j] > 0)
         break;
   }

   g_bufferUp[i] = ZZM_BUFFER_EMPTY;
   g_bufferDown[i] = low;
   g_bufferMaxChangePoints[i] = low;
   g_bufferTrend[i] = ZZM_BUFFER_TREND_DOWN;
}

//+------------------------------------------------------------------+
//| Buffer initialize                                                |
//+------------------------------------------------------------------+
void BufferInitialize()
{
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
