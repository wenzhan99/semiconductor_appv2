import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/constants/constants_repository.dart';
import '../../core/constants/latex_symbols.dart';
import '../../core/constants/constants_loader.dart';
import '../../core/constants/physical_constants_table.dart';
import '../../core/solver/number_formatter.dart';
import '../widgets/latex_text.dart';

class ConstantsUnitsPage extends StatefulWidget {
  const ConstantsUnitsPage({super.key});

  @override
  State<ConstantsUnitsPage> createState() => _ConstantsUnitsPageState();
}

class _ConstantsUnitsPageState extends State<ConstantsUnitsPage> {
  PhysicalConstantsTable? _constantsTable;
  LatexSymbolMap? _latexMap;
  final NumberFormatter _formatter = const NumberFormatter(significantFigures: 4);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final constantsRepo = ConstantsRepository();
    await constantsRepo.load();
    
    final constantsTable = await ConstantsLoader.loadConstants();
    final latexMap = await ConstantsLoader.loadLatexSymbols();

    _safeSetState(() {
      _constantsTable = constantsTable;
      _latexMap = latexMap;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Constants & Units Reference',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            _buildConstantsCard(context),
            const SizedBox(height: 16),
            _buildThermalVoltageCard(context),
            const SizedBox(height: 16),
            _buildUnitHelpersCard(context),
            const SizedBox(height: 16),
            _buildMaterialCard(context),
            const SizedBox(height: 16),
            _buildDielectricsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildConstantsCard(BuildContext context) {
    if (_constantsTable == null) return const SizedBox.shrink();

    final constants = _constantsTable!.constants;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fundamental Constants',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildDataTable(
              ['Symbol', 'Name', 'Value', 'Units', 'Note'],
              constants.map((c) {
                final symbol = _latexMap?.latexOf(c.symbol) ?? c.symbol;
                final valueLatex = _formatValueLatex(c.value);
                final unitLatex = _formatUnitLatex(c.unit);
                return [
                  symbol,
                  c.name,
                  valueLatex,
                  unitLatex,
                  c.note ?? '-',
                ];
              }).toList(),
              latexColumns: const {0, 2, 3},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThermalVoltageCard(BuildContext context) {
    final constantsRepo = ConstantsRepository();
    final k = constantsRepo.getConstantValue('k');
    final q = constantsRepo.getConstantValue('q');
    
    String expression = 'V_T = kT / q';
    String defaultValue = '-';
    
    if (k != null && q != null) {
      final vt300K = (k * 300) / q;
      defaultValue = '${_formatValue(vt300K)} V';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thermal Voltage',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Expression: $expression',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Default temperature: 300 K -> V_T ~= $defaultValue',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitHelpersCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unit Helpers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final helper in _unitHelpers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  helper,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Semiconductor Properties @ 300 K',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final mat in _materials)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mat.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _buildDataTable(
                      ['Property', 'Value'],
                      mat.properties.entries
                          .map((entry) => [entry.key, entry.value])
                          .toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDielectricsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dielectric Constants @ 300 K',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildDataTable(
              ['Material', 'eps_r'],
              _dielectrics.map((d) => [d.name, d.epsR]).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(
    List<String> headers,
    List<List<String>> rows, {
    Set<int> latexColumns = const {},
  }) {
    return DataTable(
      columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
      rows: rows
          .map(
            (row) => DataRow(
              cells: row.asMap().entries.map((entry) {
                final idx = entry.key;
                final cell = entry.value;
                if (latexColumns.contains(idx)) {
                  return DataCell(
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: LatexText(
                        cell,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                }
                return DataCell(Text(cell));
              }).toList(),
            ),
          )
          .toList(),
      headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
      dataRowMinHeight: 32,
      dataRowMaxHeight: 48,
    );
  }

  String _formatValueLatex(double value) {
    return _formatter.formatScientificLatex(value);
  }

  String _formatUnitLatex(String unit) {
    return _formatter.formatLatexUnitNormalized(unit);
  }

  String _formatValue(double value) {
    // Plain text fallback for contexts that do not render LaTeX
    return _formatter.formatPlainText(value);
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    // Avoid setState during build/layout; push to next frame if needed.
    if (phase == SchedulerPhase.persistentCallbacks || phase == SchedulerPhase.postFrameCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }
}

class _MaterialEntry {
  final String name;
  final Map<String, String> properties;

  const _MaterialEntry(this.name, this.properties);
}

class _DielectricEntry {
  final String name;
  final String epsR;

  const _DielectricEntry(this.name, this.epsR);
}

const _unitHelpers = [
  '1 cm^-3 = 1x10^6 m^-3',
  '1 eV = 1.602x10^-19 J',
  '1 Angstrom = 1x10^-10 m',
];

const _materials = [
  _MaterialEntry('Silicon (Si)', {
    'Atomic density (cm^-3)': '5.00x10^22',
    'Mass density (g/cm^3)': '2.33',
    'Lattice constant (Angstrom)': '5.43',
    'Dielectric constant eps_r': '11.7',
    'Bandgap E_g (eV)': '1.12',
    'Electron affinity (eV)': '4.01',
    'N_c (cm^-3)': '2.8x10^19',
    'N_v (cm^-3)': '1.04x10^19',
    'n_i (cm^-3)': '1.5x10^10',
    'Electron mobility (cm^2/V*s)': '1350',
    'Hole mobility (cm^2/V*s)': '480',
  }),
  _MaterialEntry('Gallium Arsenide (GaAs)', {
    'Atomic density (cm^-3)': '4.42x10^22',
    'Mass density (g/cm^3)': '5.32',
    'Lattice constant (Angstrom)': '5.65',
    'Dielectric constant eps_r': '13.1',
    'Bandgap E_g (eV)': '1.42',
    'Electron affinity (eV)': '4.07',
    'N_c (cm^-3)': '4.7x10^17',
    'N_v (cm^-3)': '7.0x10^18',
    'n_i (cm^-3)': '1.8x10^6',
    'Electron mobility (cm^2/V*s)': '8500',
    'Hole mobility (cm^2/V*s)': '400',
  }),
  _MaterialEntry('Germanium (Ge)', {
    'Atomic density (cm^-3)': '4.42x10^22',
    'Mass density (g/cm^3)': '5.33',
    'Lattice constant (Angstrom)': '5.65',
    'Dielectric constant eps_r': '16.0',
    'Bandgap E_g (eV)': '0.66',
    'Electron affinity (eV)': '4.13',
    'N_c (cm^-3)': '1.04x10^19',
    'N_v (cm^-3)': '6.0x10^18',
    'n_i (cm^-3)': '2.4x10^13',
    'Electron mobility (cm^2/V*s)': '3900',
    'Hole mobility (cm^2/V*s)': '1900',
  }),
];

const _dielectrics = [
  _DielectricEntry('SiO2', '3.8'),
  _DielectricEntry('Si3N4', '7.5'),
  _DielectricEntry('HfO2', '25'),
  _DielectricEntry('Al2O3', '9.0'),
];






