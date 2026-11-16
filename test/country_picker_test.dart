import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myradio1/providers/countries_provider.dart';
import 'package:myradio1/providers/localization_provider.dart';
import 'package:myradio1/utils/country_names.dart';
import 'package:myradio1/widgets/country_picker_sheet.dart';

class _TestCountriesNotifier extends CountriesNotifier {
  _TestCountriesNotifier(CountriesState initialState) : super(autoFetch: false) {
    state = initialState;
  }

  @override
  Future<void> fetchCountries() async {}
}

void main() {
  final sampleRawCountries = [
    {'name': 'Saudi Arabia', 'iso_3166_1': 'SA', 'stationcount': 120},
    {'name': 'Egypt', 'iso_3166_1': 'EG', 'stationcount': 85},
    {'name': 'The United Arab Emirates', 'iso_3166_1': 'AE', 'stationcount': 634},
    {'name': 'Türkiye', 'iso_3166_1': 'TR', 'stationcount': 410},
    {'name': 'The United States Of America', 'iso_3166_1': 'US', 'stationcount': 5000},
    {'name': 'Brazil', 'iso_3166_1': 'BR', 'stationcount': 1432},
    {'name': 'Brazil', 'iso_3166_1': 'br', 'stationcount': 1},
    {'name': '', 'iso_3166_1': 'UN', 'stationcount': 1},
  ];

  test('normalizeCountryList removes blanks and merges duplicate names', () {
    final cleaned = CountriesNotifier.normalizeCountryList(sampleRawCountries);
    expect(cleaned.length, 6);
    final brazil = cleaned.firstWhere((c) => c['name'] == 'Brazil');
    expect(brazil['iso_3166_1'], 'BR');
    expect(brazil['stationcount'], 1433);
  });

  test('CountryNames matches Arabic, normalized Arabic, English, and aliases', () {
    final sa = {'name': 'Saudi Arabia', 'iso_3166_1': 'SA', 'stationcount': 120};
    final ae = {'name': 'The United Arab Emirates', 'iso_3166_1': 'AE', 'stationcount': 634};
    final tr = {'name': 'Türkiye', 'iso_3166_1': 'TR', 'stationcount': 410};
    final us = {'name': 'The United States Of America', 'iso_3166_1': 'US', 'stationcount': 5000};

    expect(CountryNames.matchScore(sa, 'السعودية'), greaterThan(0));
    expect(CountryNames.matchScore(sa, 'السعوديه'), greaterThan(0));
    expect(CountryNames.matchScore(sa, 'سعودية'), greaterThan(0));
    expect(CountryNames.matchScore(sa, 'Saudi'), greaterThan(0));

    expect(CountryNames.matchScore(ae, 'الامارات'), greaterThan(0));
    expect(CountryNames.matchScore(ae, 'الإمارات'), greaterThan(0));
    expect(CountryNames.matchScore(ae, 'uae'), greaterThan(0));

    expect(CountryNames.matchScore(tr, 'تركيا'), greaterThan(0));
    expect(CountryNames.matchScore(tr, 'Turkey'), greaterThan(0));

    expect(CountryNames.matchScore(us, 'امريكا'), greaterThan(0));
    expect(CountryNames.matchScore(us, 'usa'), greaterThan(0));
  });

  testWidgets('CountryPickerSheet filters by Arabic/English and keeps results after keyboard done/search and viewInsets change', (WidgetTester tester) async {
    final cleaned = CountriesNotifier.normalizeCountryList(sampleRawCountries);
    String? chosenName;
    String? chosenIso;
    final viewInsetsNotifier = ValueNotifier<double>(0);

    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          countriesProvider.overrideWith(
            (ref) => _TestCountriesNotifier(CountriesState(countries: cleaned, isLoading: false)),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => ValueListenableBuilder<double>(
                      valueListenable: viewInsetsNotifier,
                      builder: (context, inset, child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            viewInsets: EdgeInsets.only(bottom: inset),
                          ),
                          child: CountryPickerSheet(
                            selectedCountry: null,
                            lang: 'ar',
                            onSelect: (name, iso) {
                              chosenName = name;
                              chosenIso = iso;
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final egyptTile = find.descendant(of: find.byType(ListTile), matching: find.text('مصر'));
    final saudiTile = find.descendant(of: find.byType(ListTile), matching: find.text('السعودية'));
    final turkeyTile = find.descendant(of: find.byType(ListTile), matching: find.text('تركيا'));

    // Initial visible tiles include All Countries and Saudi Arabia; scrolling reveals Egypt at the bottom
    expect(find.text(AppStrings.get('all_countries', 'ar')), findsOneWidget);
    expect(saudiTile, findsOneWidget);
    await tester.scrollUntilVisible(egyptTile, 200, scrollable: find.byType(Scrollable).last);
    expect(egyptTile, findsOneWidget);

    // Simulate opening keyboard and typing Arabic query into search field
    await tester.tap(find.byType(TextField));
    viewInsetsNotifier.value = 350;
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'مصر');
    await tester.pump();

    expect(egyptTile, findsOneWidget);
    expect(saudiTile, findsNothing);

    // Simulate pressing keyboard search/done and dismissing keyboard (viewInsets -> 0)
    await tester.testTextInput.receiveAction(TextInputAction.search);
    viewInsetsNotifier.value = 0;
    await tester.pumpAndSettle();

    // Filter must NOT reset after pressing Done / closing keyboard!
    expect(egyptTile, findsOneWidget);
    expect(saudiTile, findsNothing);

    // Clear button restores full list
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    expect(saudiTile, findsOneWidget);

    // Search via English alias and tap clickable search icon button
    await tester.enterText(find.byType(TextField), 'Turkey');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    expect(turkeyTile, findsOneWidget);
    expect(egyptTile, findsNothing);

    // Empty state on non-matching text
    await tester.enterText(find.byType(TextField), 'zzzzzzz');
    await tester.pump();
    expect(find.text(AppStrings.get('no_countries_found', 'ar')), findsOneWidget);

    // Clear and pick Egypt
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'مصر');
    await tester.pump();
    await tester.tap(egyptTile);
    await tester.pumpAndSettle();

    expect(chosenName, 'Egypt');
    expect(chosenIso, 'EG');
  });

  testWidgets('CountryPickerSheet shows All Countries tile at top when unfiltered and resets selection to null', (WidgetTester tester) async {
    final cleaned = CountriesNotifier.normalizeCountryList(sampleRawCountries);
    String? chosenName = 'Egypt';
    String? chosenIso = 'EG';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          countriesProvider.overrideWith(
            (ref) => _TestCountriesNotifier(CountriesState(countries: cleaned, isLoading: false)),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => CountryPickerSheet(
                      selectedCountry: 'Egypt',
                      lang: 'ar',
                      onSelect: (name, iso) {
                        chosenName = name;
                        chosenIso = iso;
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final allTile = find.descendant(
      of: find.byType(ListTile),
      matching: find.text(AppStrings.get('all_countries', 'ar')),
    );
    expect(allTile, findsOneWidget);

    // Hidden while filtering by text
    await tester.enterText(find.byType(TextField), 'مصر');
    await tester.pump();
    expect(allTile, findsNothing);

    // Reappears when cleared and clears country filter on tap
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    expect(allTile, findsOneWidget);

    await tester.tap(allTile);
    await tester.pumpAndSettle();

    expect(chosenName, isNull);
    expect(chosenIso, isNull);
  });
}
