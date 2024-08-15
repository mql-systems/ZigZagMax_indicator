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
#define ZZM_TREND_NONE     0
#define ZZM_TREND_UP       1
#define ZZM_TREND_DOWN    -1

#define ZZM_BUFFER_EMPTY            0.0
#define ZZM_BUFFER_TREND_UP         1.0
#define ZZM_BUFFER_TREND_UP_DOWN    2.0
#define ZZM_BUFFER_TREND_DOWN      -1.0
#define ZZM_BUFFER_TREND_DOWN_UP   -2.0

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
   SetIndexBuffer(3, g_bufferMaxChangePoints);
   SetIndexBuffer(2, g_bufferTrend, INDICATOR_CALCULATIONS);

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
         if (low[i+1] < low[i] || g_bufferTrend[i] > 0)
            ChangeZigZagUp(ratesTotal, i, high[i]);
         else
            ChangeZigZagDown(ratesTotal, i, low[i]);
      }
      else if (low[i+1] > low[i] || g_bufferTrend[i] < 0)
         ChangeZigZagDown(ratesTotal, i, low[i]);
      else
         ChangeZigZagUp(ratesTotal, i, high[i]);
   }

   return ratesTotal;
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
