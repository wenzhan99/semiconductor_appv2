import 'formula_category.dart';
import 'categories/energy_band_structure.dart';
import 'categories/density_of_states_statistics.dart';
import 'categories/carrier_concentration_equilibrium.dart';
import 'categories/carrier_transport_fundamentals.dart';
import 'categories/pn_junction.dart';
import 'categories/contacts_breakdown.dart';

/// Central registry of all formula categories.
const List<FormulaCategory> formulaCategories = [
  energyBandStructure,
  densityOfStatesStatistics,
  carrierConcentrationEquilibrium,
  carrierTransportFundamentals,
  pnJunction,
  contactsBreakdown,
];



