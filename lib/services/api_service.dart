import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/cuaca_model.dart';
import '../models/finance_model.dart';
import '../models/sholat_model.dart';
import '../models/sport_model.dart';

class ApiService {
  static Future<CuacaModel?> fetchCuaca() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.endpointCuaca));
      debugPrint('CUACA STATUS: ${response.statusCode}');
      debugPrint('CUACA BODY: ${response.body}');
      if (response.statusCode == 200) {
        return CuacaModel.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('ERROR FETCH CUACA: $e');
    }
    return null;
  }

  static Future<FinanceModel?> fetchFinance() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.endpointFinance));
      debugPrint('FINANCE STATUS: ${response.statusCode}');
      if (response.statusCode == 200) {
        return FinanceModel.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('ERROR FETCH FINANCE: $e');
    }
    return null;
  }

  static Future<SholatModel?> fetchSholat() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.endpointSholat));
      debugPrint('SHOLAT STATUS: ${response.statusCode}');
      if (response.statusCode == 200) {
        return SholatModel.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('ERROR FETCH SHOLAT: $e');
    }
    return null;
  }

  static Future<SportModel?> fetchSport() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.endpointSport));
      debugPrint('SPORT STATUS: ${response.statusCode}');
      if (response.statusCode == 200) {
        return SportModel.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('ERROR FETCH SPORT: $e');
    }
    return null;
  }
}