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
   if (limit == 0)
      return ratesTotal;
   else if (ratesTotal < 100)
      return (prevCalculated < 1) ? 0 : ratesTotal;

   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low,  true);
   ArraySetAsSeries(time, true);

   //--- Обнуления буффера если не обработанные бары больше одного
   if (limit > 1)
   {
      if (prevCalculated != 0)
         return 0;

      BufferInitialize();

      --limit;
      g_trendType  = ZZM_TREND_UP;
      g_iSearchBar = 1;
      g_iSaveBar   = 0;
      //---
      g_iHighTime = time[limit];
      g_iLowTime  = time[limit];
      g_iSaveTime = 0;
      //---
      g_iHighPrice = high[limit];
      g_iLowPrice  = low[limit];
      //---
      g_bufferUp[limit] = high[limit];
      g_bufferDown[limit] = low[limit];
      g_bufferTrend[limit] = ZZM_BUFFER_EMPTY;
      g_bufferMaxChangePoints[limit] = ZZM_BUFFER_EMPTY;
      --limit;
   }

   //--- calc
   g_bufferUp[0] = ZZM_BUFFER_EMPTY;
   g_bufferDown[0] = ZZM_BUFFER_EMPTY;
   g_bufferTrend[0] = ZZM_BUFFER_EMPTY;
   g_bufferMaxChangePoints[0] = ZZM_BUFFER_EMPTY;

   int ibar;
   double trendType;

   for (int i = limit; i > 0; i--)
   {
      g_bufferUp[i] = ZZM_BUFFER_EMPTY;
      g_bufferDown[i] = ZZM_BUFFER_EMPTY;
      g_bufferTrend[i] = ZZM_BUFFER_EMPTY;
      g_bufferMaxChangePoints[i] = ZZM_BUFFER_EMPTY;

      //--- Up
      if (g_trendType > ZZM_TREND_NONE)
      {
         // Search Up to Down Trend
         if (high[i + 1] >= high[i] && low[i + 1] > low[i])
            NewDownTrend(i, 1, time, high, low);
         else if (g_iLowPrice > low[i])
            NewDownTrend(i, 0, time, high, low);
         else if (g_iSearchBar > 1 && high[i + g_iSearchBar] >= high[i] && low[i + g_iSearchBar] > low[i])
            NewDownTrend(i, g_iSearchBar, time, high, low);
         else
         {
            // Max High
            if (g_iHighPrice <= high[i] && (ibar = iBarShift(NULL, 0, g_iHighTime, true)) != -1)
            {
               g_iSearchBar = 1;

               if (ibar != i)
               {
                  g_iHighPrice = high[i];
                  g_iHighTime = time[i];
                  g_bufferUp[ibar] = ZZM_BUFFER_EMPTY;
                  g_bufferUp[i] = high[i];
                  g_bufferTrend[i] = ZZM_BUFFER_TREND_UP;
                  g_bufferMaxChangePoints[i] = low[i];

                  if (g_bufferDown[ibar] != ZZM_BUFFER_EMPTY)
                     g_bufferTrend[ibar] = ZZM_BUFFER_TREND_DOWN;
               }
            }
            else
               g_iSearchBar++;

            // Min Low
            if (g_iSaveTime)
            {
               if (high[i + g_iSaveBar] <= high[i])
               {
                  if (low[i + g_iSaveBar] < low[i])
                  {
                     ibar = iBarShift(NULL, 0, g_iSaveTime, true);

                     if (ibar != -1 && ibar != i + g_iSaveBar)
                     {
                        int j = i + g_iSaveBar;
                        g_iLowPrice = low[j];
                        g_iLowTime = time[j];
                        g_bufferDown[ibar] = ZZM_BUFFER_EMPTY;
                        g_bufferDown[j] = low[j];
                        g_bufferTrend[j] = ZZM_BUFFER_TREND_DOWN;
                        g_bufferMaxChangePoints[j] = high[j];

                        if (g_bufferUp[ibar] != ZZM_BUFFER_EMPTY)
                           g_bufferTrend[ibar] = ZZM_BUFFER_TREND_UP;
                     }
                     g_iSaveTime = g_iSaveBar = 0;
                  }
                  else
                  {
                     g_iSaveBar = 0;
                     g_iSaveTime = g_iLowTime;
                  }
               }
               else if (low[i + g_iSaveBar] > low[i])
                  g_iSaveTime = g_iSaveBar = 0;
            }
            else if (g_iLowPrice > low[i])
            {
               g_iSaveBar = 0;
               g_iSaveTime = g_iLowTime;
            }
         }
      }
      //--- Down
      else
      {
         // Search Down to Up Trend
         if (high[i + 1] < high[i] && low[i + 1] <= low[i])
            NewUpTrend(i, 1, time, high, low);
         else if (g_iHighPrice < high[i])
            NewUpTrend(i, 0, time, high, low);
         else if (g_iSearchBar > 1 && high[i + g_iSearchBar] < high[i] && low[i + g_iSearchBar] <= low[i])
            NewUpTrend(i, g_iSearchBar, time, high, low);
         else
         {
            // Min Low
            if (g_iLowPrice >= low[i] && (ibar = iBarShift(NULL, 0, g_iLowTime, true)) != -1)
            {
               g_iSearchBar = 1;

               if (ibar != i)
               {
                  g_iLowPrice = low[i];
                  g_iLowTime = time[i];
                  g_bufferDown[ibar] = ZZM_BUFFER_EMPTY;
                  g_bufferDown[i] = low[i];
                  g_bufferTrend[i] = ZZM_BUFFER_TREND_DOWN;
                  g_bufferMaxChangePoints[i] = high[i];

                  if (g_bufferUp[ibar] != ZZM_BUFFER_EMPTY)
                     g_bufferTrend[ibar] = ZZM_BUFFER_TREND_UP;
               }
            }
            else
               g_iSearchBar++;

            // Max High
            if (g_iSaveTime)
            {
               if (low[i + g_iSaveBar] >= low[i])
               {
                  if (high[i + g_iSaveBar] > high[i])
                  {
                     ibar = iBarShift(NULL, 0, g_iSaveTime, true);

                     if (ibar != -1 && ibar != i + g_iSaveBar)
                     {
                        int j = i + g_iSaveBar;
                        g_iHighPrice = high[j];
                        g_iHighTime = time[j];
                        g_bufferUp[ibar] = ZZM_BUFFER_EMPTY;
                        g_bufferUp[j] = high[j];
                        g_bufferTrend[j] = ZZM_BUFFER_TREND_UP;
                        g_bufferMaxChangePoints[j] = low[j];

                        if (g_bufferDown[ibar] != ZZM_BUFFER_EMPTY)
                           g_bufferTrend[ibar] = ZZM_BUFFER_TREND_DOWN;
                     }

                     g_iSaveTime = g_iSaveBar = 0;
                  }
                  else
                  {
                     g_iSaveBar = 0;
                     g_iSaveTime = g_iHighTime;
                  }
               }
               else if (high[i + g_iSaveBar] < high[i])
                  g_iSaveTime = g_iSaveBar = 0;
            }
            else if (g_iHighPrice < high[i])
            {
               g_iSaveBar = 0;
               g_iSaveTime = g_iHighTime;
            }
         }
      }

      //--- Trend
      if (g_bufferTrend[i] != ZZM_BUFFER_EMPTY)
      {
         trendType = g_bufferTrend[i];

         // reversal on one candle
         if (g_bufferDown[i] != ZZM_BUFFER_EMPTY && g_bufferUp[i] != ZZM_BUFFER_EMPTY)
            g_bufferTrend[i] = trendType == ZZM_BUFFER_TREND_UP ? ZZM_BUFFER_TREND_DOWN_UP : ZZM_BUFFER_TREND_UP_DOWN;

         // filling empty trend buffers
         for (int j = i + 1; j < ratesTotal; j++)
         {
            if (g_bufferTrend[j] != ZZM_BUFFER_EMPTY)
               break;
            g_bufferTrend[j] = trendType;
         }
      }

      //---
      if (g_iSaveTime)
         g_iSaveBar++;
   }

   return ratesTotal;
}

//+------------------------------------------------------------------+
//| New Up trend                                                     |
//+------------------------------------------------------------------+
void NewUpTrend(const int i, const int plus, const datetime &time[], const double &high[], const double &low[])
{
   int ibar;
   int j = i + plus;

   g_trendType = ZZM_TREND_UP;
   g_iSearchBar = 1;

   if (g_iLowPrice >= low[j] && (ibar = iBarShift(NULL, 0, g_iLowTime, true)) != -1)
   {
      if (ibar != j)
      {
         g_iLowTime = time[j];
         g_iLowPrice = low[j];

         g_bufferDown[ibar] = ZZM_BUFFER_EMPTY;
         g_bufferDown[j] = low[j];
         g_bufferTrend[j] = ZZM_BUFFER_TREND_DOWN;
         g_bufferMaxChangePoints[j] = high[j];

         if (g_bufferUp[ibar] != ZZM_BUFFER_EMPTY)
            g_bufferTrend[ibar] = ZZM_BUFFER_TREND_UP;
      }

      if (g_iSaveTime)
         g_iSaveTime = g_iSaveBar = 0;
   }

   g_iHighTime = time[i];
   g_iHighPrice = high[i];
   g_bufferUp[i] = high[i];
   g_bufferTrend[i] = ZZM_BUFFER_TREND_UP;
   g_bufferMaxChangePoints[i] = low[i];
}

//+------------------------------------------------------------------+
//| New Down trend                                                   |
//+------------------------------------------------------------------+
void NewDownTrend(const int i, const int plus, const datetime &time[], const double &high[], const double &low[])
{
   int ibar;
   int j = i + plus;

   g_trendType = ZZM_TREND_DOWN;
   g_iSearchBar = 1;

   if (g_iHighPrice <= high[j] && (ibar = iBarShift(NULL, 0, g_iHighTime, true)) != -1)
   {
      if (ibar != j)
      {
         g_iHighTime = time[j];
         g_iHighPrice = high[j];

         g_bufferUp[ibar] = ZZM_BUFFER_EMPTY;
         g_bufferUp[j] = high[j];
         g_bufferTrend[j] = ZZM_BUFFER_TREND_UP;
         g_bufferMaxChangePoints[j] = low[j];

         if (g_bufferDown[ibar] != ZZM_BUFFER_EMPTY)
            g_bufferTrend[ibar] = ZZM_BUFFER_TREND_DOWN;
      }

      if (g_iSaveTime)
         g_iSaveTime = g_iSaveBar = 0;
   }

   g_iLowTime = time[i];
   g_iLowPrice = low[i];
   g_bufferDown[i] = low[i];
   g_bufferTrend[i] = ZZM_BUFFER_TREND_DOWN;
   g_bufferMaxChangePoints[i] = high[i];
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
