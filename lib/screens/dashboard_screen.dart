import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firebase_service.dart';
import '../services/api_service.dart';
import '../models/portfolio_item.dart';
import '../theme/colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _chartDrillDownIndex = -1;

  Future<List<PortfolioItem>> _loadEnrichedPortfolio() async {
    final firebase = Provider.of<FirebaseService>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);

    final snapshot = await firebase.getPortfolioStream().first;
    if (snapshot.isEmpty) return [];

    
    List<String> symbolsToFetch = snapshot.map((e) => e.symbol).toList();
    if (!symbolsToFetch.contains('TRY=X')) {
      symbolsToFetch.add('TRY=X'); 
    }

    
    final marketData = await api.getBatchStockQuotes(symbolsToFetch);

    
    double tryToUsdRate = 0.03; 
    if (marketData.containsKey('TRY=X')) {
      final rateData = marketData['TRY=X'];
      final rateVal = rateData?['regularMarketPrice'];
      
      
      if (rateVal != null && rateVal > 0) {
        tryToUsdRate = 1.0 / (rateVal as num).toDouble();
      }
    }

    
    for (var item in snapshot) {
      final data = marketData[item.symbol];
      if (data != null) {
        
        var price = data['regularMarketPrice'];
       
        if (price is Map) price = price['raw'];
        item.currentPrice = (price as num? ?? item.averagePrice).toDouble();
      } else {
        item.currentPrice = item.averagePrice; 
      }

    
      if (item.type == 'BIST') {
        item.currentRateUSD = tryToUsdRate;
      } else {
        item.currentRateUSD = 1.0;
      }
    }

    return snapshot;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: "\$", decimalDigits: 2);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: FutureBuilder<List<PortfolioItem>>(
          future: _loadEnrichedPortfolio(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }

            final portfolio = snapshot.data!;
            
            
            double totalValueUSD = 0;
            double totalCostUSD = 0;

            
            final usStocks = portfolio.where((i) => i.type == 'US').toList();
            final bistStocks = portfolio.where((i) => i.type == 'BIST').toList();
            final crypto = portfolio.where((i) => i.type == 'CRYPTO').toList();
            final commodities = portfolio.where((i) => i.type == 'COMMODITY').toList();
            final currencies = portfolio.where((i) => i.type == 'CURRENCY').toList();

            for (var item in portfolio) {
              totalValueUSD += item.marketValueUSD;
              totalCostUSD += item.totalCostUSD;
            }

            double totalPL = totalValueUSD - totalCostUSD;
            double totalPLPercent = totalCostUSD > 0 ? (totalPL / totalCostUSD) * 100 : 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  
                  
                  _buildHeroSection(totalValueUSD, totalPL, totalPLPercent, currencyFormat),
                  
                  const SizedBox(height: 20),

                
                  Row(
                    children: [
                      const Text("Allocation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (_chartDrillDownIndex != -1)
                        TextButton.icon(
                          onPressed: () => setState(() => _chartDrillDownIndex = -1),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text("Back"),
                        )
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Pie Chart
                  SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _buildChartSections(usStocks, bistStocks, crypto, commodities, currencies),
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                              return;
                            }
                            
                            if (event is FlTapUpEvent && _chartDrillDownIndex == -1) {
                              final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              if (index >= 0) {
                                setState(() {
                                  _chartDrillDownIndex = index;
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  
                  if (usStocks.isNotEmpty) _buildAccordion("US Stocks", usStocks, "\$"),
                  if (bistStocks.isNotEmpty) _buildAccordion("BIST Stocks", bistStocks, "₺"),
                  if (crypto.isNotEmpty) _buildAccordion("Crypto", crypto, "\$"),
                  if (commodities.isNotEmpty) _buildAccordion("Commodities", commodities, "\$"),
                  if (currencies.isNotEmpty) _buildAccordion("Currencies", currencies, "\$"),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pie_chart_outline, size: 80, color: AppColors.textGray),
          const SizedBox(height: 10),
          const Text("Portfolio is empty", style: TextStyle(color: Colors.white)),
          const SizedBox(height: 10),
          const Text("Go to Market tab to add assets.", style: TextStyle(color: AppColors.textGray)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("InvestTrack", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Icon(Icons.notifications, color: Colors.white),
      ],
    );
  }

  Widget _buildHeroSection(double value, double pl, double plPercent, NumberFormat format) {
    final isPos = pl >= 0;
    return Center(
      child: Column(
        children: [
          const Text("Total Portfolio Value", style: TextStyle(color: AppColors.textGray)),
          Text(
            format.format(value),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${isPos ? '+' : ''}${format.format(pl)} ",
                style: TextStyle(color: isPos ? AppColors.success : AppColors.error, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isPos ? AppColors.success : AppColors.error).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "${isPos ? '+' : ''}${plPercent.toStringAsFixed(2)}%",
                  style: TextStyle(color: isPos ? AppColors.success : AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  
  List<PieChartSectionData> _buildChartSections(
      List<PortfolioItem> us, List<PortfolioItem> bist, List<PortfolioItem> crypto, 
      List<PortfolioItem> comm, List<PortfolioItem> curr) {
    
    
    if (_chartDrillDownIndex == -1) {
      double vUs = us.fold(0, (sum, i) => sum + i.marketValueUSD);
      double vBist = bist.fold(0, (sum, i) => sum + i.marketValueUSD);
      double vCry = crypto.fold(0, (sum, i) => sum + i.marketValueUSD);
      double vComm = comm.fold(0, (sum, i) => sum + i.marketValueUSD);
      double vCurr = curr.fold(0, (sum, i) => sum + i.marketValueUSD);

      final style = const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12);

      return [
        PieChartSectionData(color: Colors.blue, value: vUs, title: vUs > 0 ? 'US' : '', radius: 60, titleStyle: style),
        PieChartSectionData(color: Colors.red, value: vBist, title: vBist > 0 ? 'BIST' : '', radius: 60, titleStyle: style),
        PieChartSectionData(color: Colors.orange, value: vCry, title: vCry > 0 ? 'Crypto' : '', radius: 60, titleStyle: style),
        PieChartSectionData(color: Colors.amber, value: vComm, title: vComm > 0 ? 'Comm.' : '', radius: 60, titleStyle: style),
        PieChartSectionData(color: Colors.green, value: vCurr, title: vCurr > 0 ? 'FX' : '', radius: 60, titleStyle: style),
      ];
    } 
    
    else {
      List<PortfolioItem> targetList = [];
      if (_chartDrillDownIndex == 0) targetList = us;
      else if (_chartDrillDownIndex == 1) targetList = bist;
      else if (_chartDrillDownIndex == 2) targetList = crypto;
      else if (_chartDrillDownIndex == 3) targetList = comm;
      else if (_chartDrillDownIndex == 4) targetList = curr;

      return targetList.map((item) {
        return PieChartSectionData(
          color: Colors.primaries[targetList.indexOf(item) % Colors.primaries.length],
          value: item.marketValueUSD,
          title: item.symbol,
          radius: 70,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        );
      }).toList();
    }
  }

  Widget _buildAccordion(String title, List<PortfolioItem> items, String currencySymbol) {
    double sectionTotal = items.fold(0, (sum, i) => sum + i.marketValueLocal);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        collapsedIconColor: Colors.white,
        iconColor: AppColors.primary,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            Text("$currencySymbol${NumberFormat("#,##0.00").format(sectionTotal)}", style: const TextStyle(color: AppColors.textGray)),
          ],
        ),
        children: items.map((item) {
          final isProfit = item.profitLossPercent >= 0;
          return Container(
            color: AppColors.cardInner,
            child: ListTile(
              title: Text(item.symbol, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: Row(
                children: [
                  Text("${item.quantity} units", style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_right_alt, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text("Cur: $currencySymbol${item.currentPrice.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("$currencySymbol${item.marketValueLocal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(
                    "${isProfit ? '+' : ''}${item.profitLossPercent.toStringAsFixed(2)}%",
                    style: TextStyle(color: isProfit ? AppColors.success : AppColors.error, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}