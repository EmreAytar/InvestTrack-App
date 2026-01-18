import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/portfolio_item.dart';

class ApiService {
  static String get _yahooApiKey => dotenv.env['YAHOO_API_KEY'] ?? '';
  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // --- Yahoo Finance API ---

  Future<Map<String, Map<String, dynamic>>> getBatchStockQuotes(List<String> symbols) async {
    if (symbols.isEmpty) return {};
    if (_yahooApiKey.isEmpty) return {};

    final symbolsString = symbols.join(',');
    final url = Uri.parse('https://yahoo-finance15.p.rapidapi.com/api/v1/markets/stock/quotes?ticker=$symbolsString');

    try {
      final response = await http.get(url, headers: {
        'x-rapidapi-key': _yahooApiKey,
        'x-rapidapi-host': 'yahoo-finance15.p.rapidapi.com',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['body'] != null) {
          final List<dynamic> body = data['body'];
          Map<String, Map<String, dynamic>> results = {};
          for (var item in body) {
            if (item['symbol'] != null) {
              results[item['symbol']] = item as Map<String, dynamic>;
            }
          }
          return results;
        }
      }
      return {};
    } catch (e) {
      print("Batch Fetch Error: $e");
      return {};
    }
  }

  Future<Map<String, dynamic>> getStockDetails(String symbol) async {
    final results = await getBatchStockQuotes([symbol]);
    return results[symbol] ?? {};
  }

  Future<List<dynamic>> getTopStocks() async {
    if (_yahooApiKey.isEmpty) return [];
    final url = Uri.parse('https://yahoo-finance15.p.rapidapi.com/api/v1/markets/tickers?type=STOCKS&page=1');
    try {
      final response = await http.get(url, headers: {
        'x-rapidapi-key': _yahooApiKey,
        'x-rapidapi-host': 'yahoo-finance15.p.rapidapi.com',
      });
      if (response.statusCode == 200) {
        return json.decode(response.body)['body'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> searchStocks(String query) async {
    if (query.isEmpty || _yahooApiKey.isEmpty) return [];
    final url = Uri.parse('https://yahoo-finance15.p.rapidapi.com/api/v1/markets/search?search=$query');
    try {
      final response = await http.get(url, headers: {
        'x-rapidapi-key': _yahooApiKey,
        'x-rapidapi-host': 'yahoo-finance15.p.rapidapi.com',
      });
      if (response.statusCode == 200) {
        return json.decode(response.body)['body'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- Gemini AI ---
  
  Future<String> getPortfolioAdvice(String userQuery, List<PortfolioItem> portfolio) async {
    try {
      if (_geminiApiKey.isEmpty) return "AI Key missing.";
      
      
      String portfolioContext = "User's Portfolio:\n";
      for (var item in portfolio) {
        portfolioContext += "- ${item.symbol} (${item.type}): ${item.quantity} units, Current Value: \$${item.marketValueUSD.toStringAsFixed(2)}\n";
      }

      final model = GenerativeModel(model: 'gemini-flash-latest', apiKey: _geminiApiKey);
      final prompt = "$portfolioContext\nUser Question: $userQuery\nAnswer briefly as a financial advisor.";
      
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text ?? "I couldn't analyze that right now.";
    } catch (e) {
      return "AI Service Unavailable: $e";
    }
  }
}