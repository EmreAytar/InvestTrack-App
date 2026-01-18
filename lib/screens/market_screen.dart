import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../theme/colors.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _stocks = [];
  bool _isLoading = false;
  String _viewMode = "Top Stocks"; 

  @override
  void initState() {
    super.initState();
    _loadTopStocks();
  }

  void _loadTopStocks() async {
    setState(() { _isLoading = true; _viewMode = "Top Stocks"; });
    final api = Provider.of<ApiService>(context, listen: false);
    final data = await api.getTopStocks();
    if(mounted) setState(() { _stocks = data; _isLoading = false; });
  }

  void _search() async {
    if(_searchController.text.isEmpty) return;
    setState(() { _isLoading = true; _viewMode = "Search Results"; });
    final api = Provider.of<ApiService>(context, listen: false);
    final data = await api.searchStocks(_searchController.text.trim());
    if(mounted) setState(() { _stocks = data; _isLoading = false; });
  }

  void _showStockDetails(Map<String, dynamic> stock) {
    final symbol = stock['symbol'] ?? 'N/A';
    final name = stock['companyName'] ?? stock['shortname'] ?? symbol;
    
    
    double price = 0.0;
    if (stock['regularMarketPrice'] != null) {
      if (stock['regularMarketPrice'] is Map) {
         price = (stock['regularMarketPrice']['raw'] ?? 0).toDouble();
      } else if (stock['regularMarketPrice'] is num) {
         price = (stock['regularMarketPrice']).toDouble();
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundDark,
      isScrollControlled: true,
      builder: (ctx) => StockDetailSheet(symbol: symbol, name: name, initialPrice: price),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.cardDark,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search (AAPL, THYAO.IS, GC=F, EURUSD=X)",
                  hintStyle: const TextStyle(color: AppColors.textGray),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: AppColors.primary),
                    onPressed: _search,
                  )
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_viewMode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if(_viewMode == "Search Results")
                    TextButton(onPressed: _loadTopStocks, child: const Text("Back to Top"))
                ],
              ),
            ),

            
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : ListView.builder(
                    itemCount: _stocks.length,
                    itemBuilder: (context, index) {
                      final s = _stocks[index];
                      final symbol = s['symbol'] ?? '';
                      
                      final logoUrl = "https://logo.clearbit.com/${symbol.replaceAll('.IS', '')}.com"; 

                      return ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(8)),
                          child: Image.network(
                            logoUrl, 
                            errorBuilder: (_,__,___) => const Icon(Icons.show_chart, color: Colors.white),
                          ),
                        ),
                        title: Text(symbol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(s['companyName'] ?? s['shortname'] ?? 'Asset', overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textGray)),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textGray),
                        onTap: () => _showStockDetails(s),
                      );
                    },
                  ),
            )
          ],
        ),
      ),
    );
  }
}

// --- LIVE DETAIL SHEET ---
class StockDetailSheet extends StatefulWidget {
  final String symbol;
  final String name;
  final double initialPrice;

  const StockDetailSheet({super.key, required this.symbol, required this.name, required this.initialPrice});

  @override
  State<StockDetailSheet> createState() => _StockDetailSheetState();
}

class _StockDetailSheetState extends State<StockDetailSheet> {
  final _qtyController = TextEditingController(text: "1");
  final _priceController = TextEditingController();
  
  Map<String, dynamic>? _liveData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _priceController.text = widget.initialPrice.toString();
    _fetchLiveDetail();
  }

  void _fetchLiveDetail() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final data = await api.getStockDetails(widget.symbol);
    
    if (mounted) {
      setState(() {
        _liveData = data;
        _isLoading = false;
        
       
        double currentPrice = widget.initialPrice;
        if (data['regularMarketPrice'] != null) {
          if (data['regularMarketPrice'] is num) {
             currentPrice = (data['regularMarketPrice']).toDouble();
          } else if (data['regularMarketPrice'] is Map) {
             currentPrice = (data['regularMarketPrice']['raw'] ?? 0).toDouble();
          }
        }
        
        if (currentPrice > 0) {
           _priceController.text = currentPrice.toString();
        }
      });
    }
  }

  void _addToPortfolio() async {
    setState(() => _isLoading = true);
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    
    
    String type = "US";
    String s = widget.symbol.toUpperCase();
    if (s.contains(".IS")) type = "BIST";
    else if (s.contains("-USD")) type = "CRYPTO";
    else if (s.contains("=X")) type = "CURRENCY";
    else if (s.contains("=F")) type = "COMMODITY";

    await Provider.of<FirebaseService>(context, listen: false)
        .addToPortfolio(widget.symbol, widget.name, price, qty, type);
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added to Portfolio")));
    }
  }

  @override
  Widget build(BuildContext context) {
    double change = 0.0;
    double currentPrice = double.tryParse(_priceController.text) ?? 0.0;

    if (_liveData != null && _liveData!['regularMarketChangePercent'] != null) {
       var c = _liveData!['regularMarketChangePercent'];
       if (c is num) change = c.toDouble();
       else if (c is Map) change = (c['raw'] ?? 0).toDouble();
    }

    final isPos = change >= 0;

    return Container(
      padding: const EdgeInsets.all(24),
      height: 600,
      decoration: const BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 50, height: 5, color: Colors.grey[700], margin: const EdgeInsets.only(bottom: 20))),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.symbol, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    Text(widget.name, style: const TextStyle(fontSize: 16, color: AppColors.textGray)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "\$${currentPrice.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      "${isPos ? '+' : ''}${change.toStringAsFixed(2)}% (Today)",
                      style: TextStyle(color: isPos ? AppColors.success : AppColors.error, fontWeight: FontWeight.bold),
                    ),
                ],
              )
            ],
          ),
          
          const Divider(color: AppColors.cardInner, height: 40),

          const Text("Add to Portfolio", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Quantity", filled: true, fillColor: AppColors.backgroundDark, border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Buy Price", filled: true, fillColor: AppColors.backgroundDark, border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addToPortfolio,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Confirm Transaction", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }
}