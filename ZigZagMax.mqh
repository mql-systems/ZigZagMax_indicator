//+------------------------------------------------------------------+
//|                                                    ZigZagMax.mq4 |
//|                            Copyright 2022, Diamond Systems Corp. |
//|                                   https://github.com/mql-systems |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Diamond Systems Corp."
#property link      "https://github.com/mql-systems"
#property strict

//--- defines
#define ZIGZAGMAX_TREND_NONE   0.0
#define ZIGZAGMAX_TREND_UP     1.0
#define ZIGZAGMAX_TREND_DOWN  -1.0

//--- global variables
datetime g_iHighTime;
datetime g_iLowTime;
datetime g_iSaveTime;
double   g_iHighPrice;
double   g_iLowPrice;
double   g_trendType;
uint     g_iSaveBar;
uint     g_iSearchBar;
//---
int checkBars;

//--- buffers
double g_bufferUp[];
double g_bufferDown[];
double g_bufferTrend[];

//+------------------------------------------------------------------+
//| App initialization function                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   #ifdef __MQL4__
   IndicatorBuffers(3);
   #endif
   
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   SetIndexBuffer(0, g_bufferUp);
   SetIndexBuffer(1, g_bufferDown);
   SetIndexBuffer(2, g_bufferTrend);
   
   #ifdef __MQL4__
      SetIndexEmptyValue(0, 0.0);
      SetIndexEmptyValue(1, 0.0);
      SetIndexEmptyValue(2, 0.0);
   #else
      PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   #endif
   
   ArraySetAsSeries(g_bufferUp,    true);
   ArraySetAsSeries(g_bufferDown,  true);
   ArraySetAsSeries(g_bufferTrend, true);
   
   //---
   checkBars = iBars(NULL,0);
   
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
   if (limit == 0 || ratesTotal < 100)
      return ratesTotal;
   
   //---
   if (limit > 1)
   {
      if (checkBars != iBars(NULL,0))
      {
         checkBars = iBars(NULL,0);
         return 0;
      }
      if (prevCalculated != 0)
         return 0;
      
      ArrayInitialize(g_bufferUp, 0.0);
      ArrayInitialize(g_bufferDown, 0.0);
      ArrayInitialize(g_bufferTrend, ZIGZAGMAX_TREND_NONE);
      
      ArraySetAsSeries(g_bufferUp,    true);
      ArraySetAsSeries(g_bufferDown,  true);
      ArraySetAsSeries(g_bufferTrend, true);
      
      --limit;
      g_trendType  = ZIGZAGMAX_TREND_UP;
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
      g_bufferUp[limit]   = high[limit];
      g_bufferDown[limit] = low[limit];
      --limit;
   }
   
   g_bufferUp[0] = 0.0;
   g_bufferDown[0] = 0.0;
   g_bufferTrend[0] = ZIGZAGMAX_TREND_NONE;
   
   //--- calc
   int ibar;
   
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low,  true);
   ArraySetAsSeries(time, true);
   
   for (int i=limit; i>0; i--)
   {
      g_bufferUp[i] = 0.0;
      g_bufferDown[i] = 0.0;
      g_bufferTrend[i] = ZIGZAGMAX_TREND_NONE;
      
      // Up
      if (g_trendType > ZIGZAGMAX_TREND_NONE)
      {
         // Search Up to Down Trend
         if (high[i+1] >= high[i] && low[i+1] >= low[i])
            NewDownTrend(i, 1, time, high, low);
         else if (g_iLowPrice >= low[i])
            NewDownTrend(i, 0, time, high, low);
         else if (g_iSearchBar > 1 && high[i+g_iSearchBar] >= high[i] && low[i+g_iSearchBar] >= low[i])
            NewDownTrend(i, g_iSearchBar, time, high, low);
         else
         {
            // Max High
            if (g_iHighPrice <= high[i] && (ibar = iBarShift(NULL,0,g_iHighTime,true)) != -1)
            {
               g_iSearchBar = 1;
               g_iHighPrice = high[i];
               g_iHighTime  = time[i];
               g_bufferUp[ibar] = 0.0;
               g_bufferUp[i]    = high[i];
            }
            else
               g_iSearchBar++;
            
            // Min Low
            if (g_iSaveTime)
            {
               if (high[i+g_iSaveBar] <= high[i])
               {
                  if (low[i+g_iSaveBar] < low[i])
                  {
                     if ((ibar = iBarShift(NULL,0,g_iSaveTime,true)) != -1)
                     {
                        g_iLowPrice = low[i+g_iSaveBar];
                        g_iLowTime  = time[i+g_iSaveBar];
                        
                        g_bufferDown[ibar] = 0.0;
                        g_bufferDown[i+g_iSaveBar] = low[i+g_iSaveBar];
                     }
                     g_iSaveTime = g_iSaveBar = 0;
                  }
                  else
                  {
                     g_iSaveBar  = 0;
                     g_iSaveTime = g_iLowTime;
                  }
               }
               else if (low[i+g_iSaveBar] > low[i])
                  g_iSaveTime = g_iSaveBar = 0;
            }
            else if (g_iLowPrice > low[i])
            {
               g_iSaveBar  = 0;
               g_iSaveTime = g_iLowTime;
            }
         }
      }
      // Down
      else
      {
         // Search Down to Up Trend
         if (high[i+1] <= high[i] && low[i+1] <= low[i])
            NewUpTrend(i, 1, time, high, low);
         else if (g_iHighPrice <= high[i])
            NewUpTrend(i, 0, time, high, low);
         else if (g_iSearchBar > 1 && high[i+g_iSearchBar] <= high[i] && low[i+g_iSearchBar] <= low[i])
            NewUpTrend(i, g_iSearchBar, time, high, low);
         else
         {
            // Min Low
            if (g_iLowPrice >= low[i] && (ibar = iBarShift(NULL,0,g_iLowTime,true)) != -1)
            {
               g_iSearchBar = 1;
               g_iLowPrice  = low[i];
               g_iLowTime   = time[i];
               g_bufferDown[ibar] = 0.0;
               g_bufferDown[i]    = low[i];
            }
            else
               g_iSearchBar++;
            
            // Max High
            if (g_iSaveTime)
            {
               if (low[i+g_iSaveBar] >= low[i])
               {
                  if (high[i+g_iSaveBar] > high[i])
                  {
                     if ((ibar = iBarShift(NULL,0,g_iSaveTime,true)) != -1)
                     {
                        g_iHighPrice = high[i+g_iSaveBar];
                        g_iHighTime  = time[i+g_iSaveBar];
                        
                        g_bufferUp[ibar] = 0.0;
                        g_bufferUp[i+g_iSaveBar] = high[i+g_iSaveBar];
                     }
                     g_iSaveTime = g_iSaveBar = 0;
                  }
                  else
                  {
                     g_iSaveBar  = 0;
                     g_iSaveTime = g_iHighTime;
                  }
               }
               else if (high[i+g_iSaveBar] < high[i])
                  g_iSaveTime = g_iSaveBar = 0;
            }
            else if (g_iHighPrice < high[i])
            {
               g_iSaveBar  = 0;
               g_iSaveTime = g_iHighTime;
            }
         }
      }
      
      g_bufferTrend[i] = g_trendType;
      if (g_iSaveTime)
         g_iSaveBar++;
   }
   
   ChartRedraw();
   
   return ratesTotal;
}

//+------------------------------------------------------------------+
//| New Up trend                                                     |
//+------------------------------------------------------------------+
void NewUpTrend(const int i, const int plus, const datetime &time[], const double &high[], const double &low[])
{
   int ibar;
   
   g_trendType  = ZIGZAGMAX_TREND_UP;
   g_iSearchBar = 1;
   
   if (g_iLowPrice >= low[i+plus] && (ibar = iBarShift(NULL,0,g_iLowTime,true)) != -1)
   {
      g_iLowTime  = time[i+plus];
      g_iLowPrice = low[i+plus];
      
      g_bufferDown[ibar]   = 0.0;
      g_bufferDown[i+plus] = low[i+plus];
      
      if (g_iSaveTime)
         g_iSaveTime = g_iSaveBar = 0;
   }
   
   g_iHighTime  = time[i];
   g_iHighPrice = high[i];
   g_bufferUp[i] = high[i];
}

//+------------------------------------------------------------------+
//| New Down trend                                                   |
//+------------------------------------------------------------------+
void NewDownTrend(const int i, const int plus, const datetime &time[], const double &high[], const double &low[])
{
   int ibar;
   
   g_trendType  = ZIGZAGMAX_TREND_DOWN;
   g_iSearchBar = 1;
   
   if (g_iHighPrice <= high[i+plus] && (ibar = iBarShift(NULL,0,g_iHighTime,true)) != -1)
   {
      g_iHighTime  = time[i+plus];
      g_iHighPrice = high[i+plus];
      
      g_bufferUp[ibar]   = 0.0;
      g_bufferUp[i+plus] = high[i+plus];
      
      if (g_iSaveTime)
         g_iSaveTime = g_iSaveBar = 0;
   }
   
   g_iLowTime  = time[i];
   g_iLowPrice = low[i];
   g_bufferDown[i] = low[i];
}

//+------------------------------------------------------------------+