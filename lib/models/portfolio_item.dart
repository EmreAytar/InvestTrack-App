class PortfolioItem {
  // Static Data (Stored in Firestore)
  final String id;
  final String symbol;
  final String name;
  final double quantity;
  final double averagePrice; 
  final String type; 

  // Live Data (Fetched from API at runtime, not stored in DB)
  double currentPrice;
  double currentRateUSD; 

  PortfolioItem({
    required this.id,
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.averagePrice,
    required this.type,
    this.currentPrice = 0.0,
    this.currentRateUSD = 1.0,
  });

 
  double get marketValueLocal => currentPrice * quantity;

  
  double get marketValueUSD => marketValueLocal * currentRateUSD;

  
  double get totalCostUSD => averagePrice * quantity * currentRateUSD;

  double get profitLossUSD => marketValueUSD - totalCostUSD;

 
  double get profitLossPercent {
    if (averagePrice == 0) return 0.0;
    return ((currentPrice - averagePrice) / averagePrice) * 100;
  }

  factory PortfolioItem.fromFirestore(Map<String, dynamic> data, String id) {
    return PortfolioItem(
      id: id,
      symbol: data['symbol'] ?? '',
      name: data['name'] ?? '',
      quantity: (data['quantity'] ?? 0).toDouble(),
      averagePrice: (data['averagePrice'] ?? 0).toDouble(),
      type: data['type'] ?? 'US',
    );
  }
}