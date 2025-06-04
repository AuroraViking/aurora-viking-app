import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

class SubstormAlertService {
  // Using the Kyoto University FTP server URL
  final String aeUrl = 'ftp://ftp.stelab.nagoya-u.ac.jp/pub/ae/Realtime/ae.realtime';

  Future<Map<String, dynamic>> getSubstormStatus() async {
    try {
      print('Fetching AE index from: $aeUrl');
      
      // Convert FTP URL to HTTP URL for the mirror
      final httpUrl = 'http://wdc.kugi.kyoto-u.ac.jp/ae_realtime/ae.realtime';
      
      // Add headers to mimic a browser request
      final headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'text/plain,text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Charset': 'shift_jis,utf-8;q=0.7,*;q=0.3',
      };
      
      final response = await http.get(
        Uri.parse(httpUrl),
        headers: headers,
      );

      print('Response status code: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body length: ${response.body.length}');
      print('First 500 characters of response: ${response.body.substring(0, min(500, response.body.length))}');
      
      if (response.statusCode == 200) {
        try {
          // Split the response into lines
          final lines = response.body.trim().split('\n');
          print('Number of lines: ${lines.length}');
          
          if (lines.isEmpty) {
            print('No data lines found in response');
            return _createErrorResponse('No data found in response');
          }

          // Get the most recent line
          final recentLine = lines.last.trim().split(RegExp(r'\s+'));
          print('Recent line: $recentLine');
          print('Recent line length: ${recentLine.length}');

          if (recentLine.length >= 5) {
            // Parse the AE value (5th column)
            final aeValue = int.tryParse(recentLine[4]) ?? 0;
            print('Parsed AE value: $aeValue');

            // Parse the timestamp (first two columns: YYYYMMDD HHMM)
            final dateStr = recentLine[0];
            final timeStr = recentLine[1];
            print('Date string: $dateStr, Time string: $timeStr');
            
            final year = int.parse(dateStr.substring(0, 4));
            final month = int.parse(dateStr.substring(4, 6));
            final day = int.parse(dateStr.substring(6, 8));
            final hour = int.parse(timeStr.substring(0, 2));
            final minute = int.parse(timeStr.substring(2, 4));
            
            final timestamp = DateTime(year, month, day, hour, minute);
            print('Parsed timestamp: $timestamp');

            return {
              'isActive': aeValue > 600, // Threshold for strong auroral electrojet
              'aeValue': aeValue,
              'timestamp': timestamp,
              'error': null,
            };
          } else {
            print('Invalid data format in line: $recentLine');
            return _createErrorResponse('Invalid data format');
          }
        } catch (e) {
          print('Error parsing response: $e');
          return _createErrorResponse('Error parsing response: $e');
        }
      } else {
        print('Failed to fetch AE index. Status code: ${response.statusCode}');
        return _createErrorResponse('Failed to fetch AE index. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching AE index: $e');
      return _createErrorResponse('Error fetching AE index: $e');
    }
  }

  Map<String, dynamic> _createErrorResponse(String error) {
    return {
      'isActive': false,
      'aeValue': 0,
      'timestamp': DateTime.now(),
      'error': error,
    };
  }

  String getSubstormDescription(int aeValue) {
    if (aeValue > 1000) {
      return 'Major substorm activity detected!';
    } else if (aeValue > 800) {
      return 'Strong substorm activity detected';
    } else if (aeValue > 600) {
      return 'Moderate substorm activity detected';
    } else if (aeValue > 400) {
      return 'Minor substorm activity detected';
    } else {
      return 'No significant substorm activity';
    }
  }
} 