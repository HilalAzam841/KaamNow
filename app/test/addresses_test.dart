import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/customer/addresses_screen.dart';
import 'package:kaamnow/ui/customer/new_request_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_test.dart' show paged;
import 'favourites_test.dart' show tall;
import 'helpers.dart';
import 'promos_test.dart' show pumpScreen;

Map<String, dynamic> addressJson(
        {int id = 1, String label = 'home', String name = '', String address = 'House 5, Street 2, Gulberg III',
        String area = 'Gulberg', bool isDefault = false, String lat = '31.510000', String lng = '74.340000'}) =>
    {
      'id': id,
      'label': label,
      'name': name,
      'address': address,
      'area': area,
      'latitude': lat,
      'longitude': lng,
      'is_default': isDefault,
      'created_at': '2026-11-20T10:00:00Z',
      'updated_at': '2026-11-20T10:00:00Z',
    };

void main() {
  setUpAll(() => initializeDateFormatting());

  test('a saved address parses', () {
    final a = SavedAddress.fromJson(addressJson(label: 'other', name: 'Ammi', isDefault: true));
    expect(a.label, 'other');
    expect(a.name, 'Ammi');
    expect(a.latitude, closeTo(31.51, 1e-9));
    expect(a.isDefault, isTrue);
  });

  testWidgets('the customer sees their places, picks which comes first and removes one', (tester) async {
    tall(tester);
    var list = [
      addressJson(isDefault: true),
      addressJson(id: 2, label: 'other', name: "Ammi's house", address: 'House 9, Model Town', area: ''),
    ];
    final h = await pumpScreen(tester, const AddressesScreen(), setup: (h) {
      h.backend.on('GET /addresses/', (_) => ok(list));
      h.backend.on('POST /addresses/2/make-default/', (_) {
        list = [addressJson(), addressJson(id: 2, label: 'other', name: "Ammi's house", isDefault: true)];
        return ok(list[1]);
      });
      h.backend.on('DELETE /addresses/1/', (_) {
        list = [list[1]];
        return ok(null);
      });
    });
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text("Ammi's house"), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);

    await tester.tap(find.byKey(const Key('address-menu-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use first'));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /addresses/2/make-default/'), hasLength(1));

    await tester.tap(find.byKey(const Key('address-menu-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('DELETE /addresses/1/'), hasLength(1));
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('an empty list explains saved places', (tester) async {
    tall(tester);
    await pumpScreen(tester, const AddressesScreen(), setup: (h) => h.backend.on('GET /addresses/', (_) => ok([])));
    await tester.pumpAndSettle();
    expect(find.text('No saved addresses'), findsOneWidget);
    expect(find.byKey(const Key('add-address')), findsOneWidget);
  });

  testWidgets('saving a named place sends its pin, name and address', (tester) async {
    tall(tester);
    SavedAddress? result;
    final h = await pumpScreen(tester,
        Builder(
            builder: (c) => TextButton(
                onPressed: () async => result = await editAddress(c,
                    pin: const LatLng(31.47, 74.27), address: 'Flat 3, Johar Town', area: 'Johar Town'),
                child: const Text('open'))),
        setup: (h) => h.backend.on('POST /addresses/', (req) {
              final b = jsonDecode(req.body) as Map<String, dynamic>;
              return ok(addressJson(id: 4, label: b['label'], name: b['name'], address: b['address']), status: 201);
            }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-address')));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /addresses/'), isEmpty, reason: 'a named place needs its name');

    await tester.enterText(find.byKey(const Key('address-name')), 'Office annex');
    await tester.tap(find.byKey(const Key('address-first')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-address')));
    await tester.pumpAndSettle();
    final body = jsonDecode(h.backend.callsTo('POST /addresses/').single.body) as Map<String, dynamic>;
    expect(body, {
      'label': 'other',
      'name': 'Office annex',
      'address': 'Flat 3, Johar Town',
      'area': 'Johar Town',
      'latitude': '31.470000',
      'longitude': '74.270000',
      'make_default': true,
    });
    expect(result?.id, 4, reason: 'the form closes with the saved place');
  });

  testWidgets('a place cannot be saved without a pin', (tester) async {
    tall(tester);
    final h = await pumpScreen(tester, const AddressFormScreen(address: 'House 1, Street 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-address')));
    await tester.pumpAndSettle();
    expect(find.text('Put the pin on the map first.'), findsOneWidget);
    expect(h.backend.callsTo('POST /addresses/'), isEmpty);
  });

  testWidgets('posting a job starts at the saved place used first, and chips switch places', (tester) async {
    tall(tester);
    final h = await pumpScreen(tester, const NewRequestScreen(categoryId: 1), setup: (h) {
      h.backend.on('GET /services/categories/', (_) => ok(paged([])));
      h.backend.on('GET /requests/slots/', (_) => ok([]));
      h.backend.on('GET /addresses/', (_) => ok([
            addressJson(id: 1, isDefault: true),
            addressJson(id: 2, label: 'work', address: 'Office 12, MM Alam Road', area: 'Gulberg II',
                lat: '31.520000', lng: '74.350000'),
          ]));
    });
    await tester.pumpAndSettle();
    final address = find.byKey(const Key('req-address'));
    expect(tester.widget<TextFormField>(address).controller!.text, 'House 5, Street 2, Gulberg III');
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('saved-addr-1'))).selected, isTrue);
    expect(find.byKey(const Key('save-this-place')), findsNothing);
    expect(h.backend.callsTo('GET /requests/slots/').last.url.query, contains('latitude=31.51'));

    await tester.tap(find.byKey(const Key('saved-addr-2')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(address).controller!.text, 'Office 12, MM Alam Road');
    expect(h.backend.callsTo('GET /requests/slots/').last.url.query, contains('latitude=31.52'));

    // Typing a different address means it is no longer that saved place, so it can be saved.
    await tester.enterText(address, 'Shop 4, Liberty Market');
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('saved-addr-2'))).selected, isFalse);
    expect(find.byKey(const Key('save-this-place')), findsOneWidget);
  });

  testWidgets('a job opened from a pin keeps that pin over the saved default', (tester) async {
    tall(tester);
    await pumpScreen(tester, const NewRequestScreen(initialPin: LatLng(31.40, 74.20)), setup: (h) {
      h.backend.on('GET /services/categories/', (_) => ok(paged([])));
      h.backend.on('GET /addresses/', (_) => ok([addressJson(isDefault: true)]));
    });
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('saved-addr-1'))).selected, isFalse);
  });
}
