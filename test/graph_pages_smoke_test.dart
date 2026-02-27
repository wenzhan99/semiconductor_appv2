import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:semiconductor_appv2/ui/pages/density_of_states_graph_page.dart';
import 'package:semiconductor_appv2/ui/pages/direct_indirect_graph_page.dart';
import 'package:semiconductor_appv2/ui/pages/fermi_dirac_graph_page.dart';

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  await tester.binding.setSurfaceSize(const Size(2200, 1400));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Direct/Indirect graph renders and handles tap interactions',
      (tester) async {
    await _pumpPage(tester, const DirectIndirectGraphPage());

    expect(find.text('Direct vs Indirect Bandgap'), findsOneWidget);
    expect(find.byType(LineChart), findsAtLeastNWidgets(1));

    final chart = find.byType(LineChart);
    final center = tester.getCenter(chart);
    await tester.tapAt(center);
    await tester.pump();

    await tester.tapAt(Offset(center.dx + 120, center.dy - 40));
    await tester.pump();

    expect(find.textContaining('Point Inspector'), findsOneWidget);
  });

  testWidgets('Fermi-Dirac graph renders and hover/tap path is stable',
      (tester) async {
    await _pumpPage(tester, const FermiDiracGraphPage());

    expect(find.text('Fermi-Dirac Probability'), findsOneWidget);
    expect(find.byType(LineChart), findsAtLeastNWidgets(1));

    final chart = find.byType(LineChart);
    await tester.tapAt(tester.getCenter(chart));
    await tester.pump();

    expect(find.textContaining('Point Inspector'), findsOneWidget);
  });

  testWidgets('Density of States graph renders and interaction is stable',
      (tester) async {
    await _pumpPage(tester, const DensityOfStatesGraphPage());

    expect(find.text('Density of States g(E) vs Energy'), findsWidgets);
    expect(find.byType(LineChart), findsAtLeastNWidgets(1));

    final chart = find.byType(LineChart);
    await tester.tapAt(tester.getCenter(chart));
    await tester.pump();

    expect(find.textContaining('Point Inspector'), findsOneWidget);
  });
}
