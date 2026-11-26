import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/worker/earnings_report_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'favourites_test.dart' show tall;
import 'helpers.dart';
import 'promos_test.dart' show pumpScreen;

Map<String, dynamic> totals({int jobs = 0, String net = '0.00', String gross = '0.00', String adjustments = '0.00'}) =>
    {
      'jobs': jobs, 'gross': gross, 'commission': '0.00', 'discount': '0.00', 'earnings': net,
      'adjustments': adjustments, 'net': net,
    };

Map<String, dynamic> reportJson({String start = '2026-11-01', String end = '2026-11-26', int jobs = 3,
        String net = '5400.00', String previousNet = '4500.00', String adjustments = '0.00'}) =>
    {
      'start': start,
      'end': end,
      'group': 'day',
      'totals': {...totals(jobs: jobs, net: net, gross: '6000.00', adjustments: adjustments), 'commission': '600.00'},
      'average_per_job': jobs == 0 ? '0.00' : '1800.00',
      'previous': {'start': '2026-10-06', 'end': '2026-10-31', ...totals(jobs: 2, net: previousNet)},
      'series': [
        {'start': '2026-11-01', 'jobs': 0, 'gross': '0.00', 'net': '0.00'},
        {'start': '2026-11-02', 'jobs': 2, 'gross': '5000.00', 'net': '4500.00'},
        {'start': '2026-11-03', 'jobs': 1, 'gross': '1000.00', 'net': '900.00'},
      ],
      'by_service': [
        {'category': 1, 'name': 'Electrician', 'jobs': 2, 'gross': '5000.00', 'net': '4500.00'},
        {'category': 2, 'name': 'Plumber', 'jobs': 1, 'gross': '1000.00', 'net': '900.00'},
      ],
      'by_payment': {
        'cash': totals(jobs: 1, net: '1800.00'),
        'online': totals(jobs: 2, net: '3600.00'),
        'unpaid': totals(),
      },
    };

void main() {
  setUpAll(() => initializeDateFormatting());
  final today = DateTime(2026, 11, 26); // a Thursday

  test('periods and change', () {
    expect(periodRange(ReportPeriod.thisWeek, today), (DateTime(2026, 11, 23), DateTime(2026, 11, 26)));
    expect(periodRange(ReportPeriod.thisMonth, today), (DateTime(2026, 11, 1), DateTime(2026, 11, 26)));
    expect(periodRange(ReportPeriod.lastMonth, today), (DateTime(2026, 10, 1), DateTime(2026, 10, 31)));
    expect(periodRange(ReportPeriod.lastMonth, DateTime(2026, 1, 15)), (DateTime(2025, 12, 1), DateTime(2025, 12, 31)));
    expect(periodRange(ReportPeriod.thisYear, today), (DateTime(2026, 1, 1), DateTime(2026, 11, 26)));
    expect(changePercent('5400.00', '4500.00'), 20);
    expect(changePercent('900', '1800'), -50);
    expect(changePercent('900', '0.00'), isNull);
    final r = EarningsReport.fromJson(reportJson());
    expect(r.days, 26);
    expect(r.byPayment['online']!.jobs, 2);
    expect(r.series[1].start, DateTime(2026, 11, 2));
  });

  testWidgets('the report shows totals, change, bars, services and payment split', (tester) async {
    tall(tester);
    final h = await pumpScreen(tester, EarningsReportScreen(today: today), role: 'worker', setup: (h) {
      h.backend.on('GET /payments/earnings/report/', (req) => ok(req.url.queryParameters['start'] == '2026-10-01'
          ? reportJson(start: '2026-10-01', end: '2026-10-31', jobs: 0, net: '0.00', previousNet: '0.00')
          : reportJson(adjustments: '-300.00')));
    });
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('GET /payments/earnings/report/').single.url.query,
        'start=2026-11-01&end=2026-11-26');
    expect(find.text('Rs 5,400'), findsOneWidget);
    expect(find.text('20% more than the 26 days before'), findsOneWidget);
    expect(find.text('Refund shares taken: Rs 300'), findsOneWidget);
    expect(find.text('Rs 1,800'), findsWidgets);
    expect(find.text('Electrician'), findsOneWidget);
    expect(find.text('Plumber'), findsOneWidget);
    expect(find.text('Cash (you hold it)'), findsOneWidget);
    expect(find.text('Online (KaamNow holds it)'), findsOneWidget);
    expect(find.text('Not paid yet'), findsNothing, reason: 'empty splits are left out');

    // The best day is highlighted first; tapping another bar shows that day.
    expect(find.textContaining('Mon 2 Nov: Rs 4,500 · 2 jobs'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bar-2')));
    await tester.pump();
    expect(find.textContaining('Tue 3 Nov: Rs 900 · 1 job'), findsOneWidget);

    await tester.tap(find.byKey(const Key('period-lastMonth')));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('GET /payments/earnings/report/').last.url.query, 'start=2026-10-01&end=2026-10-31');
    expect(find.text('No completed jobs in these dates.'), findsOneWidget);
    expect(find.text('Nothing earned in the 31 days before'), findsOneWidget);
    expect(find.text('Electrician'), findsNothing);
  });

  testWidgets('the statement downloads for the chosen dates', (tester) async {
    tall(tester);
    (Uint8List, String, String)? saved;
    await pumpScreen(tester, EarningsReportScreen(
      today: today,
      save: (bytes, name, type) async {
        saved = (bytes, name, type);
        return true;
      },
    ), role: 'worker', setup: (h) {
      h.backend.on('GET /payments/earnings/report/', (_) => ok(reportJson()));
      h.backend.on('GET /payments/earnings/statement/', (req) {
        expect(req.url.queryParameters, {'start': '2026-11-23', 'end': '2026-11-26'});
        return http.Response('Date,Booking\n', 200, headers: {'content-type': 'text/csv; charset=utf-8'});
      });
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('period-thisWeek')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('download-statement')));
    await tester.tap(find.byKey(const Key('download-statement')));
    await tester.pumpAndSettle();
    expect(saved!.$2, 'kaamnow-earnings-2026-11-23-to-2026-11-26.csv');
    expect(saved!.$3, startsWith('text/csv'));
    expect(String.fromCharCodes(saved!.$1), 'Date,Booking\n');
    expect(find.text('Statement downloaded.'), findsOneWidget);
  });
}
