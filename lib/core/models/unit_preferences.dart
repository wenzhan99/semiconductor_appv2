/// Unit system preference for the workspace.
enum UnitSystem {
  si,
  cm;

  static UnitSystem fromJson(String jsonValue) {
    return UnitSystem.values.firstWhere(
      (e) => e.name == jsonValue,
      orElse: () => UnitSystem.cm,
    );
  }

  String toJson() => name;
}

/// Temperature unit preference for the workspace.
enum TemperatureUnit {
  kelvin,
  celsius;

  static TemperatureUnit fromJson(String jsonValue) {
    return TemperatureUnit.values.firstWhere(
      (e) => e.name == jsonValue,
      orElse: () => TemperatureUnit.kelvin,
    );
  }

  String toJson() => name;
}



