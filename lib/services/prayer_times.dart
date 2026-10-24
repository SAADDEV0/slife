import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'settings_service.dart';

/// The five daily prayers, plus sunrise (when Fajr time ends).
enum Salah {
  fajr('Fajr', 'الفجر'),
  sunrise('Sunrise', 'الشروق'),
  dhuhr('Dhuhr', 'الظهر'),
  asr('Asr', 'العصر'),
  maghrib('Maghrib', 'المغرب'),
  isha('Isha', 'العشاء');

  const Salah(this.label, this.arabic);
  final String label;
  final String arabic;

  bool get isPrayer => this != sunrise;

  /// Dhuhr is Jumuʿah on Fridays.
  String labelOn(DateTime day) =>
      this == dhuhr && day.weekday == DateTime.friday ? 'Jumuʿah' : label;
}

/// How Fajr and Isha are calculated. Each country tends to follow one.
enum PrayerMethod {
  morocco('Morocco (Habous)', 'Fajr 19°, Isha 17°, Dhuhr & Maghrib +5 min'),
  muslimWorldLeague('Muslim World League', 'Fajr 18°, Isha 17°'),
  egyptian('Egypt', 'Fajr 19.5°, Isha 17.5°'),
  ummAlQura('Umm al-Qura, Makkah', 'Fajr 18.5°, Isha 90 min'),
  karachi('Karachi', 'Fajr 18°, Isha 18°'),
  northAmerica('North America (ISNA)', 'Fajr 15°, Isha 15°'),
  france('France (UOIF)', 'Fajr 12°, Isha 12°'),
  dubai('Gulf region', 'Fajr 18.2°, Isha 18.2°'),
  kuwait('Kuwait', 'Fajr 18°, Isha 17.5°'),
  qatar('Qatar', 'Fajr 18°, Isha 90 min'),
  singapore('Singapore, Malaysia', 'Fajr 20°, Isha 18°'),
  turkey('Türkiye (Diyanet)', 'Fajr 18°, Isha 17°'),
  tehran('Tehran', 'Fajr 17.7°, Isha 14°'),
  moonSighting('Moonsighting Committee', 'Fajr 18°, Isha 18°, seasonal');

  const PrayerMethod(this.label, this.detail);
  final String label;
  final String detail;

  adhan.CalculationParameters parameters() => switch (this) {
    // Ministry of Habous: Dhuhr and Maghrib 5 min after the astronomical time.
    morocco => adhan.CalculationParameters(
      fajrAngle: 19,
      ishaAngle: 17,
      methodAdjustments: adhan.PrayerAdjustments(dhuhr: 5, maghrib: 5),
    ),
    france => adhan.CalculationParameters(fajrAngle: 12, ishaAngle: 12),
    muslimWorldLeague =>
      adhan.CalculationMethod.muslim_world_league.getParameters(),
    egyptian => adhan.CalculationMethod.egyptian.getParameters(),
    ummAlQura => adhan.CalculationMethod.umm_al_qura.getParameters(),
    karachi => adhan.CalculationMethod.karachi.getParameters(),
    northAmerica => adhan.CalculationMethod.north_america.getParameters(),
    dubai => adhan.CalculationMethod.dubai.getParameters(),
    kuwait => adhan.CalculationMethod.kuwait.getParameters(),
    qatar => adhan.CalculationMethod.qatar.getParameters(),
    singapore => adhan.CalculationMethod.singapore.getParameters(),
    turkey => adhan.CalculationMethod.turkey.getParameters(),
    tehran => adhan.CalculationMethod.tehran.getParameters(),
    moonSighting =>
      adhan.CalculationMethod.moon_sighting_committee.getParameters(),
  };

  static PrayerMethod of(SettingsService s) => values.firstWhere(
    (m) => m.name == s.prayerMethod,
    orElse: () => muslimWorldLeague,
  );

  /// The usual method for an ISO country code.
  static PrayerMethod forCountry(String? code) => switch (code?.toUpperCase()) {
    'MA' => morocco,
    'EG' || 'SD' || 'LY' || 'SY' || 'LB' || 'IQ' => egyptian,
    'SA' || 'YE' => ummAlQura,
    'AE' || 'OM' || 'BH' => dubai,
    'KW' => kuwait,
    'QA' => qatar,
    'PK' || 'IN' || 'BD' || 'AF' => karachi,
    'US' || 'CA' => northAmerica,
    'FR' => france,
    'SG' || 'MY' || 'ID' || 'BN' => singapore,
    'TR' => turkey,
    'IR' => tehran,
    _ => muslimWorldLeague,
  };
}

/// Prayer times of one day, in local time.
@immutable
class DayPrayers {
  const DayPrayers(this.day, this.times);

  final DateTime day;
  final Map<Salah, DateTime> times;

  DateTime operator [](Salah s) => times[s]!;

  /// Calculates [day]'s times from the saved location and method, or null
  /// when no location is set yet.
  static DayPrayers? of(SettingsService s, DateTime day) {
    final lat = s.prayerLat, lng = s.prayerLng;
    if (lat == null || lng == null) return null;
    final params = PrayerMethod.of(s).parameters()
      ..madhab = s.prayerHanafi ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
    final t = adhan.PrayerTimes(
      adhan.Coordinates(lat, lng),
      adhan.DateComponents(day.year, day.month, day.day),
      params,
    );
    return DayPrayers(DateTime(day.year, day.month, day.day), {
      Salah.fajr: t.fajr.toLocal(),
      Salah.sunrise: t.sunrise.toLocal(),
      Salah.dhuhr: t.dhuhr.toLocal(),
      Salah.asr: t.asr.toLocal(),
      Salah.maghrib: t.maghrib.toLocal(),
      Salah.isha: t.isha.toLocal(),
    });
  }

  /// The next of the five prayers after [now] (tomorrow's Fajr after Isha).
  static (Salah, DateTime)? next(SettingsService s, DateTime now) {
    final today = of(s, now);
    if (today == null) return null;
    for (final p in Salah.values) {
      if (p.isPrayer && today[p].isAfter(now)) return (p, today[p]);
    }
    final tomorrow = of(s, DateTime(now.year, now.month, now.day + 1))!;
    return (Salah.fajr, tomorrow[Salah.fajr]);
  }
}

/// Finds where the user is, for prayer times. Each call returns null on
/// success or a message to show.
class PrayerLocation {
  PrayerLocation._();

  /// Uses the phone's (coarse) location.
  static Future<String?> useCurrent(SettingsService s) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Turn on location, or search for your city instead.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return 'Location was not allowed. You can search for your city instead.';
      }
      final pos =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 20),
            ),
          );
      await _save(s, pos.latitude, pos.longitude);
      return null;
    } catch (e) {
      debugPrint('SLife: location failed: $e');
      return 'Could not find your location. Try searching for your city.';
    }
  }

  /// Looks up a city name, e.g. "Rabat" or "Lyon, France".
  static Future<String?> search(SettingsService s, String query) async {
    try {
      final found = await Geocoding().locationFromAddress(query.trim());
      if (found.isEmpty) return 'No place called "$query" was found.';
      await _save(s, found.first.latitude, found.first.longitude);
      return null;
    } catch (e) {
      debugPrint('SLife: city search failed: $e');
      return 'Could not search right now. Check your connection.';
    }
  }

  static Future<void> _save(SettingsService s, double lat, double lng) async {
    var place = '';
    String? country;
    try {
      final marks = await Geocoding().placemarkFromCoordinates(lat, lng);
      if (marks.isNotEmpty) {
        final m = marks.first;
        final city = [
          m.locality,
          m.subAdministrativeArea,
          m.administrativeArea,
        ].firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
        place = [city, m.country].whereType<String>().join(', ');
        country = m.isoCountryCode;
      }
    } catch (_) {
      // Offline: keep the coordinates, show them instead of a name.
    }
    await s.setPrayerLocation(lat, lng, place);
    if (s.prayerMethod == null) {
      await s.setPrayerMethod(PrayerMethod.forCountry(country).name);
    }
  }

  /// "Rabat, Morocco" or "34.02° N, 6.83° W".
  static String label(SettingsService s) {
    if (s.prayerPlace.isNotEmpty) return s.prayerPlace;
    final lat = s.prayerLat, lng = s.prayerLng;
    if (lat == null || lng == null) return 'No location';
    return '${lat.abs().toStringAsFixed(2)}° ${lat >= 0 ? 'N' : 'S'}, '
        '${lng.abs().toStringAsFixed(2)}° ${lng >= 0 ? 'E' : 'W'}';
  }
}
