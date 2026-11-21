//+------------------------------------------------------------------+
//| AON_MACross.mq5                                                  |
//| AlgoOps Note verification EA                                     |
//|   EMA crossover (stop and reverse) + ATR-based SL/TP             |
//|   + fixed-fractional position sizing.                            |
//| For Strategy Tester and demo accounts only. Not trading advice.  |
//+------------------------------------------------------------------+
#property copyright "AlgoOps Note"
#property link      "https://algo-ops-note.com"
#property version   "1.00"
#property description "Verification EA for AlgoOps Note. Tester and demo accounts only."

#include <Trade/Trade.mqh>

input group "Signal"
input int    InpFastPeriod        = 20;       // Fast EMA period
input int    InpSlowPeriod        = 50;       // Slow EMA period

input group "Risk"
input int    InpAtrPeriod         = 14;       // ATR period
input double InpSlAtrMult         = 2.0;      // Stop loss = ATR x this
input double InpTpAtrMult         = 3.0;      // Take profit = ATR x this (0 = none)
input double InpRiskPercent       = 1.0;      // Risk per trade (% of balance)

input group "Filter"
input int    InpMaxSpreadPoints   = 30;       // Max spread for entries in points (0 = off)

input group "Misc"
input ulong  InpMagic             = 20261121; // Magic number
input int    InpMinTradesForScore = 30;       // OnTester: min trades, else score 0

CTrade   g_trade;
int      g_fastHandle = INVALID_HANDLE;
int      g_slowHandle = INVALID_HANDLE;
int      g_atrHandle  = INVALID_HANDLE;
datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   // Safety: never run on a real account outside the Strategy Tester.
   if(!MQLInfoInteger(MQL_TESTER) &&
      AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL)
     {
      Print("AON_MACross: real accounts are not allowed. Use the tester or a demo account.");
      return(INIT_FAILED);
     }

   if(InpFastPeriod < 1 || InpSlowPeriod <= InpFastPeriod)
     {
      Print("AON_MACross: require 1 <= FastPeriod < SlowPeriod");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpAtrPeriod < 1 || InpSlAtrMult <= 0.0 || InpTpAtrMult < 0.0 ||
      InpRiskPercent <= 0.0 || InpRiskPercent > 10.0)
     {
      Print("AON_MACross: invalid risk parameters");
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_fastHandle = iMA(_Symbol, _Period, InpFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_slowHandle = iMA(_Symbol, _Period, InpSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_atrHandle  = iATR(_Symbol, _Period, InpAtrPeriod);
   if(g_fastHandle == INVALID_HANDLE || g_slowHandle == INVALID_HANDLE ||
      g_atrHandle == INVALID_HANDLE)
     {
      Print("AON_MACross: failed to create indicator handles, error ", GetLastError());
      return(INIT_FAILED);
     }

   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(10);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_fastHandle != INVALID_HANDLE) IndicatorRelease(g_fastHandle);
   if(g_slowHandle != INVALID_HANDLE) IndicatorRelease(g_slowHandle);
   if(g_atrHandle  != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
  }

//+------------------------------------------------------------------+
//| Decisions are made once per bar, on closed bars only, so results |
//| do not depend on intrabar ticks for the signal itself.           |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime barTime = iTime(_Symbol, _Period, 0);
   if(barTime == 0 || barTime == g_lastBarTime)
      return;

   double fast[], slow[], atr[];
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   ArraySetAsSeries(atr, true);
   // Index 0 = last closed bar (shift 1), index 1 = the bar before it.
   if(CopyBuffer(g_fastHandle, 0, 1, 2, fast) != 2 ||
      CopyBuffer(g_slowHandle, 0, 1, 2, slow) != 2 ||
      CopyBuffer(g_atrHandle,  0, 1, 1, atr)  != 1)
      return; // data not ready yet; retry on the next tick

   g_lastBarTime = barTime;

   int signal = 0;
   if(fast[1] <= slow[1] && fast[0] > slow[0]) signal = 1;   // golden cross
   if(fast[1] >= slow[1] && fast[0] < slow[0]) signal = -1;  // dead cross
   if(signal == 0)
      return;

   ulong ticket = 0;
   int current = CurrentPositionDirection(ticket);
   if(current == signal)
      return;

   // Stop and reverse: close the opposite position first.
   if(current != 0)
     {
      if(!g_trade.PositionClose(ticket))
        {
         PrintFormat("AON_MACross: close failed, retcode=%u", g_trade.ResultRetcode());
         return;
        }
     }

   if(InpMaxSpreadPoints > 0 &&
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints)
     {
      Print("AON_MACross: entry skipped, spread too wide");
      return;
     }

   OpenPosition(signal, atr[0]);
  }

//+------------------------------------------------------------------+
//| Returns 1 (long), -1 (short) or 0 (none) for this EA's position. |
//+------------------------------------------------------------------+
int CurrentPositionDirection(ulong &ticket)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      ticket = t;
      return(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1);
     }
   return(0);
  }

//+------------------------------------------------------------------+
void OpenPosition(const int direction, const double atrValue)
  {
   double slDist = atrValue * InpSlAtrMult;
   double tpDist = atrValue * InpTpAtrMult;

   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(slDist <= minDist || (InpTpAtrMult > 0.0 && tpDist <= minDist))
     {
      Print("AON_MACross: entry skipped, stop distance below broker minimum");
      return;
     }

   double price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = (direction > 0) ? price - slDist : price + slDist;
   double tp = 0.0;
   if(InpTpAtrMult > 0.0)
      tp = (direction > 0) ? price + tpDist : price - tpDist;

   double lots = LotsForRisk(direction, price, sl);
   if(lots <= 0.0)
     {
      Print("AON_MACross: entry skipped, risk-based lot is below the minimum volume");
      return;
     }

   sl = NormalizeDouble(sl, _Digits);
   if(tp > 0.0)
      tp = NormalizeDouble(tp, _Digits);

   bool ok = (direction > 0) ? g_trade.Buy(lots, _Symbol, 0.0, sl, tp, "AON_MACross")
                             : g_trade.Sell(lots, _Symbol, 0.0, sl, tp, "AON_MACross");
   if(!ok)
      PrintFormat("AON_MACross: order failed, retcode=%u", g_trade.ResultRetcode());
  }

//+------------------------------------------------------------------+
//| Volume such that hitting the stop loses InpRiskPercent of        |
//| balance. Uses OrderCalcProfit so cross-currency pairs work.      |
//+------------------------------------------------------------------+
double LotsForRisk(const int direction, const double price, const double sl)
  {
   ENUM_ORDER_TYPE type = (direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double lossPerLot = 0.0;
   if(!OrderCalcProfit(type, _Symbol, 1.0, price, sl, lossPerLot) || lossPerLot >= 0.0)
      return(0.0);

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   double lots = riskMoney / -lossPerLot;

   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0.0)
      return(0.0);

   lots = MathFloor(lots / step) * step;   // round down: never exceed the risk budget
   if(lots < minLot)
      return(0.0);
   return(NormalizeDouble(MathMin(lots, maxLot), 8));
  }

//+------------------------------------------------------------------+
//| Custom optimization criterion: recovery factor (net profit /     |
//| max equity drawdown), or 0 when the sample is too small.         |
//+------------------------------------------------------------------+
double OnTester()
  {
   if(TesterStatistics(STAT_TRADES) < InpMinTradesForScore)
      return(0.0);
   return(TesterStatistics(STAT_RECOVERY_FACTOR));
  }
//+------------------------------------------------------------------+
