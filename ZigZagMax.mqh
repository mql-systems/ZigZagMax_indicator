//+------------------------------------------------------------------+
//|                                                    ZigZagMax.mq4 |
//|                            Copyright 2022, Diamond Systems Corp. |
//|                                   https://github.com/mql-systems |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Diamond Systems Corp."
#property link      "https://github.com/mql-systems"
#property version   "1.00"
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
int      g_prevBars;

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
      PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
      PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   #endif
   
   ArraySetAsSeries(g_bufferUp,    true);
   ArraySetAsSeries(g_bufferDown,  true);
   ArraySetAsSeries(g_bufferTrend, true);
   
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
   if (limit == ratesTotal)
      limit -= 3;

   int i,ibar;
   
   if (limit == 1)
      g_bufferTrend[limit-1] = ZIGZAGMAX_TREND_NONE;
   else if (limit > 1)
   {
      ArrayInitialize(g_bufferUp, 0.0);
      ArrayInitialize(g_bufferDown, 0.0);
      ArrayInitialize(g_bufferTrend, ZIGZAGMAX_TREND_NONE);
      
      i = limit-1;
      g_trendType  = ZIGZAGMAX_TREND_UP;
      g_iSearchBar = 1;
      //---
      g_iHighTime  = iTime(NULL,0,i);
      g_iHighPrice = iHigh(NULL,0,i);
      g_iLowTime   = iTime(NULL,0,i);
      g_iLowPrice  = iLow(NULL,0,i);
      //---
      g_bufferUp[i]   = iHigh(NULL,0,i);
      g_bufferDown[i] = iLow(NULL,0,i);
   }
   else
      return ratesTotal;
   
   for (i=limit; i>0; i--)
   {
      // Up
      if (g_trendType > ZIGZAGMAX_TREND_NONE)
      {
         // Search Up to Down Trend
         if (iHigh(NULL,0,i+1) >= iHigh(NULL,0,i) && iLow(NULL,0,i+1) >= iLow(NULL,0,i))
            NewDownTrend(i, 1);
         else if (g_iLowPrice >= iLow(NULL,0,i))
            NewDownTrend(i, 0);
         else if (g_iSearchBar > 1 && iHigh(NULL,0,i+g_iSearchBar) >= iHigh(NULL,0,i) && iLow(NULL,0,i+g_iSearchBar) >= iLow(NULL,0,i))
            NewDownTrend(i, g_iSearchBar);
         else
         {
            // Max High
            if (g_iHighPrice <= iHigh(NULL,0,i) && (ibar = iBarShift(NULL,0,g_iHighTime,true)) != -1)
            {
               g_iSearchBar = 1;
               g_iHighPrice = iHigh(NULL,0,i);
               g_iHighTime  = iTime(NULL,0,i);
               g_bufferUp[ibar] = 0.0;
               g_bufferUp[i]    = iHigh(NULL,0,i);
            }
            else
               g_iSearchBar++;
            
            // Min Low
            if (g_iSaveTime)
            {
               if (iHigh(NULL,0,i+g_iSaveBar) <= iHigh(NULL,0,i))
               {
                  if (iLow(NULL,0,i+g_iSaveBar) < iLow(NULL,0,i))
                  {
                     if ((ibar = iBarShift(NULL,0,g_iSaveTime,true)) != -1)
                     {
                        g_iLowPrice = iLow(NULL,0,i+g_iSaveBar);
                        g_iLowTime  = iTime(NULL,0,i+g_iSaveBar);
                        
                        g_bufferDown[ibar] = 0.0;
                        g_bufferDown[i+g_iSaveBar] = iLow(NULL,0,i+g_iSaveBar);
                     }
                     g_iSaveTime = g_iSaveBar = 0;
                  }
                  else
                  {
                     g_iSaveBar  = 0;
                     g_iSaveTime = g_iLowTime;
                  }
               }
               else if (iLow(NULL,0,i+g_iSaveBar) > iLow(NULL,0,i))
                  g_iSaveTime = g_iSaveBar = 0;
            }
            else if (g_iLowPrice > iLow(NULL,0,i))
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
         if (iHigh(NULL,0,i+1) <= iHigh(NULL,0,i) && iLow(NULL,0,i+1) <= iLow(NULL,0,i))
            NewUpTrend(i, 1);
         else if (g_iHighPrice <= iHigh(NULL,0,i))
            NewUpTrend(i, 0);
         else if (g_iSearchBar > 1 && iHigh(NULL,0,i+g_iSearchBar) <= iHigh(NULL,0,i) && iLow(NULL,0,i+g_iSearchBar) <= iLow(NULL,0,i))
            NewUpTrend(i, g_iSearchBar);
         else
         {
            // Min Low
            if (g_iLowPrice >= iLow(NULL,0,i) && (ibar = iBarShift(NULL,0,g_iLowTime,true)) != -1)
            {
               g_iSearchBar = 1;
               g_iLowPrice  = iLow(NULL,0,i);
               g_iLowTime   = iTime(NULL,0,i);
               g_bufferDown[ibar] = 0.0;
               g_bufferDown[i]    = iLow(NULL,0,i);
            }
            else
               g_iSearchBar++;
            
            // Max High
            if (g_iSaveTime)
            {
               if (iLow(NULL,0,i+g_iSaveBar) >= iLow(NULL,0,i))
               {
                  if (iHigh(NULL,0,i+g_iSaveBar) > iHigh(NULL,0,i))
                  {
                     if ((ibar = iBarShift(NULL,0,g_iSaveTime,true)) != -1)
                     {
                        g_iHighPrice = iHigh(NULL,0,i+g_iSaveBar);
                        g_iHighTime  = iTime(NULL,0,i+g_iSaveBar);
                        
                        g_bufferUp[ibar] = 0.0;
                        g_bufferUp[i+g_iSaveBar] = iHigh(NULL,0,i+g_iSaveBar);
                     }
                     g_iSaveTime = g_iSaveBar = 0;
                  }
                  else
                  {
                     g_iSaveBar  = 0;
                     g_iSaveTime = g_iHighTime;
                  }
               }
               else if (iHigh(NULL,0,i+g_iSaveBar) < iHigh(NULL,0,i))
                  g_iSaveTime = g_iSaveBar = 0;
            }
            else if (g_iHighPrice < iHigh(NULL,0,i))
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

   return ratesTotal;
}

//+------------------------------------------------------------------+
//| New Up trend                                                     |
//+------------------------------------------------------------------+
void NewUpTrend(int i, int plus)
{
   int ibar;
   
   g_trendType  = ZIGZAGMAX_TREND_UP;
   g_iSearchBar = 1;
   
   if (g_iLowPrice >= iLow(NULL,0,i+plus) && (ibar = iBarShift(NULL,0,g_iLowTime,true)) != -1)
   {
      g_iLowTime  = iTime(NULL,0,i+plus);
      g_iLowPrice = iLow(NULL,0,i+plus);
      
      g_bufferDown[ibar]   = 0.0;
      g_bufferDown[i+plus] = iLow(NULL,0,i+plus);
      
      if (g_iSaveTime)
         g_iSaveTime = g_iSaveBar = 0;
   }
   
   g_iHighTime  = iTime(NULL,0,i);
   g_iHighPrice = iHigh(NULL,0,i);
   g_bufferUp[i] = iHigh(NULL,0,i);
}

//+------------------------------------------------------------------+
//| New Down trend                                                   |
//+------------------------------------------------------------------+
void NewDownTrend(int i, int plus)
{
   int ibar;
   
   g_trendType  = ZIGZAGMAX_TREND_DOWN;
   g_iSearchBar = 1;
   
   if (g_iHighPrice <= iHigh(NULL,0,i) && (ibar = iBarShift(NULL,0,g_iHighTime,true)) != -1)
   {
      g_iHighTime  = iTime(NULL,0,i+plus);
      g_iHighPrice = iHigh(NULL,0,i+plus);
      
      g_bufferUp[ibar]   = 0.0;
      g_bufferUp[i+plus] = iHigh(NULL,0,i+plus);
      
      if (g_iSaveTime)
         g_iSaveTime = g_iSaveBar = 0;
   }
   
   g_iLowTime  = iTime(NULL,0,i);
   g_iLowPrice = iLow(NULL,0,i);
   g_bufferDown[i] = iLow(NULL,0,i);
}

//+------------------------------------------------------------------+