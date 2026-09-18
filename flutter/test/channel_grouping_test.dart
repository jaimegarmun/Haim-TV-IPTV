import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/services/channel_grouping.dart';

Brand brand(String id) => brands.firstWhere((b) => b.id == id);

void main() {
  group('normalizeName', () {
    test('lowercases, strips accents and separates +', () {
      expect(normalizeName('ES: Aragón TV FHD'), 'es aragon tv fhd');
      expect(normalizeName('M+ LaLiga'), 'm + laliga');
      expect(normalizeName('Movistar+'), 'movistar +');
      expect(normalizeName('|ES| España'), 'es espana');
    });
  });

  group('brands', () {
    test('Movistar', () {
      final movistar = brand('movistar');
      expect(movistar.matches('M+ LaLiga HD'), isTrue);
      expect(movistar.matches('ES: Movistar Plus+'), isTrue);
      expect(movistar.matches('M+ Vamos'), isTrue);
      expect(movistar.matches('Movistar+ Series FHD'), isTrue);
      expect(movistar.matches('MTV'), isFalse);
    });

    test('RTVE', () {
      final rtve = brand('rtve');
      expect(rtve.matches('La 1 HD'), isTrue);
      expect(rtve.matches('ES: LA1'), isTrue);
      expect(rtve.matches('Teledeporte'), isTrue);
      expect(rtve.matches('TVE Internacional'), isTrue);
      expect(rtve.matches('Clan TVE'), isTrue);
      // Word boundaries: no false positives.
      expect(rtve.matches('Gala 1'), isFalse);
      expect(rtve.matches('La 10'), isFalse);
      expect(rtve.matches('Canal Clandestino'), isFalse);
    });

    test('Atresmedia and Mediaset', () {
      expect(brand('atresmedia').matches('Antena 3 HD'), isTrue);
      expect(brand('atresmedia').matches('laSexta'), isTrue);
      expect(brand('mediaset_es').matches('Telecinco FHD'), isTrue);
      expect(brand('mediaset_es').matches('Cuatro'), isTrue);
    });

    test('Canal+ and accents', () {
      expect(brand('canalplus').matches('Canal+ Sport 2'), isTrue);
      expect(brand('canalplus').matches('CANAL + CINEMA'), isTrue);
      expect(brand('aragon').matches('Aragón TV'), isTrue);
    });
  });

  group('detectCountry', () {
    String? code(String name) => detectCountry(name)?.code;

    test('prefixes with separators', () {
      expect(code('ES| DEPORTES'), 'ES');
      expect(code('|MX| CINE'), 'MX');
      expect(code('[FR] Sport'), 'FR');
      expect(code('UK: Entertainment'), 'UK');
      expect(code('IT - Cinema'), 'IT');
      expect(code('EX-YU | Sport'), 'EXYU');
      expect(code('AR | MBC'), 'ARABIC');
    });

    test('common codes followed by a space', () {
      expect(code('ES DEPORTES'), 'ES');
      expect(code('US NEWS'), 'US');
    });

    test('ambiguous words are not countries', () {
      // "IT" and "NO" only count with an explicit separator.
      expect(code('IT CROWD'), isNull);
      expect(code('NO SIGNAL'), isNull);
      // Lowercase words are never codes.
      expect(code('es la hora'), isNull);
      expect(code('Sports'), isNull);
      expect(code('Movies 4K'), isNull);
    });

    test('names in several languages', () {
      expect(code('SPAIN - MOVIES'), 'ES');
      expect(code('España Deportes'), 'ES');
      expect(code('Canales Latinos'), 'LATAM');
      expect(code('ARGENTINA'), 'AR');
      expect(code('South Africa Sports'), 'ZA');
      expect(code('AFRICA'), 'AFRICA');
      expect(code('Deutschland HD'), 'DE');
    });

    test('flags', () {
      expect(code('🇪🇸 Deportes'), 'ES');
      expect(code('🇬🇧 News'), 'UK');
    });

    test('suffix codes', () {
      expect(code('Sports | PT'), 'PT');
      expect(code('Cine (MX)'), 'MX');
    });

    test('flag emoji of a country', () {
      expect(detectCountry('ES| Sport')!.flag, '🇪🇸');
      expect(detectCountry('LATAM | Cine')!.flag, '🌐');
    });
  });
}
