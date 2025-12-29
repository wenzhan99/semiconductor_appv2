import 'dart:convert';

import 'package:flutter/services.dart';

import 'latex_symbols.dart';
import 'physical_constants_table.dart';

/// Central loader for constants + LaTeX symbol map.
/// Uses rootBundle, so these files must be declared in pubspec.yaml.
class ConstantsLoader {
  static const String _constantsPath = 'assets/constants/ee2103_physical_constants.json';
  static const String _latexPath = 'assets/constants/ee2103_latex_symbols.json';

  static Future<PhysicalConstantsTable> loadConstants() async {
    final raw = await rootBundle.loadString(_constantsPath);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return PhysicalConstantsTable.fromJson(map);
  }

  static Future<LatexSymbolMap> loadLatexSymbols() async {
    final raw = await rootBundle.loadString(_latexPath);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return LatexSymbolMap.fromJson(map);
  }
}



