/// Heuristics that sort live channels into automatic folders: by network
/// (Movistar, TVE, Atresmedia...) and by country, grouped into world regions.
library;

const Map<String, String> _accents = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a', //
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', //
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', //
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', //
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', //
  'ñ': 'n', 'ç': 'c', 'ß': 'ss', 'ø': 'o', 'æ': 'ae', 'œ': 'oe',
};

/// Lowercase, accent-free, words separated by single spaces. `+` is kept as
/// its own word so "M+", "Movistar+" and "Canal +" can be recognised.
String normalizeName(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final mapped = _accents[char] ?? char;
    if (RegExp(r'^[a-z0-9]+$').hasMatch(mapped)) {
      buffer.write(mapped);
    } else if (mapped == '+') {
      buffer.write(' + ');
    } else {
      buffer.write(' ');
    }
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

bool _containsWords(String normalizedText, String normalizedTerm) {
  if (normalizedTerm.isEmpty) return false;
  return ' $normalizedText '.contains(' $normalizedTerm ');
}

// ---------------------------------------------------------------------------
// Networks
// ---------------------------------------------------------------------------

class Brand {
  final String id;
  final String name;

  /// Search terms. Each one is used both for the database search and, as
  /// whole words, to confirm that a channel name really belongs here.
  final List<String> terms;
  final int color;

  const Brand(this.id, this.name, this.terms, this.color);

  bool matches(String channelName) {
    final normalized = normalizeName(channelName);
    return terms.any((t) => _containsWords(normalized, normalizeName(t)));
  }
}

const List<Brand> brands = [
  // Spain
  Brand('movistar', 'Movistar+', ['movistar', 'm+', 'm +'], 0xFF0B7BC1),
  Brand('rtve', 'RTVE', [
    'tve',
    'rtve',
    'la 1',
    'la1',
    'la 2',
    'la2',
    '24h',
    'canal 24 horas',
    'teledeporte',
    'tdp',
    'clan',
  ], 0xFFC8102E),
  Brand('atresmedia', 'Atresmedia', [
    'antena 3',
    'antena3',
    'la sexta',
    'lasexta',
    'neox',
    'nova',
    'mega',
    'atreseries',
  ], 0xFFFF6A00),
  Brand('mediaset_es', 'Mediaset España', [
    'telecinco',
    'tele 5',
    'cuatro',
    'fdf',
    'factoria de ficcion',
    'divinity',
    'energy',
    'boing',
    'be mad',
    'bemad',
  ], 0xFF1B5FAA),
  Brand('dazn', 'DAZN', ['dazn'], 0xFF2B2B2B),
  Brand('laliga', 'LaLiga TV', [
    'laliga tv',
    'laliga hypermotion',
    'gol',
    'gol play',
  ], 0xFF00A650),
  Brand('3cat', '3Cat (TV3)', [
    'tv3',
    '3cat',
    'esport3',
    'super3',
    'sx3',
    '324',
  ], 0xFF222222),
  Brand('telemadrid', 'Telemadrid', ['telemadrid', 'la otra'], 0xFFD71920),
  Brand('canalsur', 'Canal Sur', ['canal sur', 'andalucia tv'], 0xFF009B3A),
  Brand('eitb', 'EITB', ['etb', 'eitb'], 0xFF0072BC),
  Brand('crtvg', 'CRTVG', ['tvg', 'crtvg', 'g24'], 0xFF1E88E5),
  Brand('apunt', 'À Punt', ['a punt', 'apunt'], 0xFFE30613),
  Brand('cmm', 'CMM', ['cmm'], 0xFF8E24AA),
  Brand('aragon', 'Aragón TV', ['aragon tv', 'aragón tv'], 0xFFFFB300),
  Brand('rtpa', 'RTPA', ['rtpa', 'tpa'], 0xFF1565C0),
  Brand('ib3', 'IB3', ['ib3'], 0xFF00897B),
  Brand('7rm', '7RM', ['7rm'], 0xFFD32F2F),
  Brand('tvcanaria', 'Televisión Canaria', [
    'tv canaria',
    'television canaria',
    'televisión canaria',
  ], 0xFFFDD835),
  // International
  Brand('bein', 'beIN Sports', ['bein'], 0xFF5E2D91),
  Brand('espn', 'ESPN', ['espn'], 0xFFD50000),
  Brand('eurosport', 'Eurosport', ['eurosport'], 0xFF1A237E),
  Brand('sky', 'Sky', ['sky'], 0xFF0D47A1),
  Brand('canalplus', 'Canal+', ['canal+', 'canal +', 'canal plus'], 0xFF111111),
  Brand('hbo', 'HBO', ['hbo'], 0xFF4527A0),
  Brand('disney', 'Disney', ['disney'], 0xFF113CCF),
  Brand('fox', 'FOX', ['fox'], 0xFF263238),
  Brand('warner', 'Warner / TNT', ['warner', 'tnt'], 0xFF1565C0),
  Brand('discovery', 'Discovery', ['discovery', 'dmax'], 0xFF0277BD),
  Brand('natgeo', 'National Geographic', [
    'national geographic',
    'nat geo',
    'natgeo',
  ], 0xFFFFC400),
  Brand('history', 'History', ['history', 'historia'], 0xFF6D4C41),
  Brand('amc', 'AMC', ['amc'], 0xFF424242),
  Brand('paramount', 'Paramount', ['paramount'], 0xFF0D47A1),
  Brand('axn', 'AXN / Sony', ['axn', 'sony'], 0xFF37474F),
  Brand('nick', 'Nickelodeon', ['nickelodeon', 'nick jr', 'nick'], 0xFFFF6F00),
  Brand('cartoon', 'Cartoon Network', [
    'cartoon network',
    'cartoonito',
    'boomerang',
  ], 0xFF212121),
  Brand('mtv', 'MTV', ['mtv'], 0xFFFFEB3B),
  Brand('comedy', 'Comedy Central', ['comedy central'], 0xFFFFD600),
  Brand('cnn', 'CNN', ['cnn'], 0xFFCC0000),
  Brand('bbc', 'BBC', ['bbc'], 0xFF000000),
  Brand('itv', 'ITV', ['itv'], 0xFF2E7D32),
  Brand('univision', 'Univision / TUDN', [
    'univision',
    'unimas',
    'tudn',
    'galavision',
  ], 0xFF6A1B9A),
  Brand('telemundo', 'Telemundo', ['telemundo'], 0xFF0D47A1),
  Brand('televisa', 'Televisa', ['televisa', 'las estrellas'], 0xFFF57F17),
  Brand('azteca', 'TV Azteca', ['azteca'], 0xFF00695C),
  Brand('rai', 'RAI', ['rai'], 0xFF1565C0),
  Brand('mediaset_it', 'Mediaset Italia', [
    'canale 5',
    'italia 1',
    'rete 4',
    'mediaset',
  ], 0xFF283593),
  Brand('tf1', 'Groupe TF1', ['tf1', 'tmc', 'tfx', 'lci'], 0xFF1E3A8A),
  Brand('francetv', 'France Télévisions', [
    'france 2',
    'france 3',
    'france 4',
    'france 5',
    'franceinfo',
    'france info',
  ], 0xFF1976D2),
  Brand('rtl', 'RTL', ['rtl'], 0xFFC62828),
  Brand('ard_zdf', 'ARD / ZDF', ['ard', 'das erste', 'zdf'], 0xFF0D47A1),
];

// ---------------------------------------------------------------------------
// Countries and regions
// ---------------------------------------------------------------------------

enum WorldRegion {
  europe('Europe'),
  latinAmerica('Latin America'),
  northAmerica('North America'),
  arabic('Middle East & Arabic'),
  africa('Africa'),
  asia('Asia'),
  oceania('Oceania');

  final String label;
  const WorldRegion(this.label);
}

class Country {
  /// ISO 3166 alpha-2 code, or a pseudo code for a whole region.
  final String code;
  final String name;
  final WorldRegion region;

  /// Codes used as prefixes in IPTV lists, e.g. "ES|", "[ESP]", "MX:".
  final List<String> codes;

  /// Names searched as whole words, e.g. "spain", "espana".
  final List<String> names;

  const Country(this.code, this.name, this.region, this.codes, this.names);

  /// Flag emoji, or a globe for whole regions.
  String get flag {
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) return '🌐';
    return String.fromCharCodes(code.codeUnits.map((c) => 0x1F1E6 + c - 65));
  }
}

const _eu = WorldRegion.europe;
const _la = WorldRegion.latinAmerica;
const _na = WorldRegion.northAmerica;
const _ar = WorldRegion.arabic;
const _af = WorldRegion.africa;
const _as = WorldRegion.asia;
const _oc = WorldRegion.oceania;

const List<Country> countries = [
  // Europe
  Country(
    'ES',
    'Spain',
    _eu,
    ['ES', 'ESP', 'SPA'],
    [
      'spain',
      'espana',
      'spanish',
      'espanol',
      'espanola',
      'espanolas',
      'espanoles',
    ],
  ),
  Country(
    'PT',
    'Portugal',
    _eu,
    ['PT', 'POR'],
    ['portugal', 'portuguese', 'portugues'],
  ),
  Country(
    'FR',
    'France',
    _eu,
    ['FR', 'FRA'],
    ['france', 'francia', 'french', 'francais'],
  ),
  Country(
    'UK',
    'United Kingdom',
    _eu,
    ['UK', 'GB', 'GBR'],
    ['uk', 'united kingdom', 'reino unido', 'england', 'british', 'scotland'],
  ),
  Country('IE', 'Ireland', _eu, ['IE', 'IRL'], ['ireland', 'irlanda', 'irish']),
  Country(
    'DE',
    'Germany',
    _eu,
    ['DE', 'GER', 'DEU'],
    ['germany', 'alemania', 'deutschland', 'german', 'deutsch'],
  ),
  Country('AT', 'Austria', _eu, ['AT', 'AUT'], ['austria', 'osterreich']),
  Country(
    'CH',
    'Switzerland',
    _eu,
    ['CH', 'SUI', 'SWI'],
    ['switzerland', 'suiza', 'schweiz', 'swiss'],
  ),
  Country(
    'IT',
    'Italy',
    _eu,
    ['IT', 'ITA'],
    ['italy', 'italia', 'italian', 'italiano'],
  ),
  Country(
    'NL',
    'Netherlands',
    _eu,
    ['NL', 'NED', 'HOL'],
    ['netherlands', 'holland', 'holanda', 'paises bajos', 'dutch', 'nederland'],
  ),
  Country(
    'BE',
    'Belgium',
    _eu,
    ['BE', 'BEL'],
    ['belgium', 'belgica', 'belgie', 'belgique'],
  ),
  Country(
    'PL',
    'Poland',
    _eu,
    ['PL', 'POL'],
    ['poland', 'polonia', 'polska', 'polish'],
  ),
  Country(
    'RO',
    'Romania',
    _eu,
    ['RO', 'ROM', 'ROU'],
    ['romania', 'rumania', 'romanian'],
  ),
  Country('BG', 'Bulgaria', _eu, ['BG', 'BUL'], ['bulgaria', 'bulgarian']),
  Country(
    'GR',
    'Greece',
    _eu,
    ['GR', 'GRE'],
    ['greece', 'grecia', 'greek', 'hellas'],
  ),
  Country(
    'TR',
    'Turkey',
    _eu,
    ['TR', 'TUR'],
    ['turkey', 'turquia', 'turkiye', 'turkish'],
  ),
  Country('RU', 'Russia', _eu, ['RU', 'RUS'], ['russia', 'rusia', 'russian']),
  Country(
    'UA',
    'Ukraine',
    _eu,
    ['UA', 'UKR'],
    ['ukraine', 'ucrania', 'ukrainian'],
  ),
  Country(
    'SE',
    'Sweden',
    _eu,
    ['SE', 'SWE'],
    ['sweden', 'suecia', 'swedish', 'sverige'],
  ),
  Country(
    'NO',
    'Norway',
    _eu,
    ['NOR'],
    ['norway', 'noruega', 'norwegian', 'norge'],
  ),
  Country(
    'DK',
    'Denmark',
    _eu,
    ['DK', 'DEN'],
    ['denmark', 'dinamarca', 'danish', 'danmark'],
  ),
  Country(
    'FI',
    'Finland',
    _eu,
    ['FI', 'FIN'],
    ['finland', 'finlandia', 'finnish', 'suomi'],
  ),
  Country('CZ', 'Czechia', _eu, ['CZ', 'CZE'], ['czech', 'czechia', 'chequia']),
  Country('SK', 'Slovakia', _eu, ['SK', 'SVK'], ['slovakia', 'eslovaquia']),
  Country(
    'HU',
    'Hungary',
    _eu,
    ['HU', 'HUN'],
    ['hungary', 'hungria', 'hungarian', 'magyar'],
  ),
  Country(
    'HR',
    'Croatia',
    _eu,
    ['HR', 'CRO'],
    ['croatia', 'croacia', 'hrvatska'],
  ),
  Country('RS', 'Serbia', _eu, ['RS', 'SRB'], ['serbia', 'srbija']),
  Country('BA', 'Bosnia', _eu, ['BA', 'BIH'], ['bosnia']),
  Country('SI', 'Slovenia', _eu, ['SI', 'SLO'], ['slovenia', 'eslovenia']),
  Country('MK', 'North Macedonia', _eu, ['MK', 'MKD'], ['macedonia']),
  Country('AL', 'Albania', _eu, ['ALB'], ['albania', 'shqip']),
  Country('LT', 'Lithuania', _eu, ['LT', 'LTU'], ['lithuania', 'lituania']),
  Country('LV', 'Latvia', _eu, ['LV', 'LAT'], ['latvia', 'letonia']),
  Country('EE', 'Estonia', _eu, ['EE', 'EST'], ['estonia']),
  Country('CY', 'Cyprus', _eu, ['CY', 'CYP'], ['cyprus', 'chipre']),
  Country('MT', 'Malta', _eu, ['MT', 'MLT'], ['malta']),
  Country(
    'EXYU',
    'Ex-Yugoslavia / Balkans',
    _eu,
    ['EXYU', 'EX-YU', 'YU'],
    ['exyu', 'ex yu', 'balkan', 'balkans', 'balcanes'],
  ),
  Country(
    'EU',
    'Europe (general)',
    _eu,
    ['EU', 'EUR'],
    ['europe', 'europa', 'european'],
  ),
  // Latin America
  Country(
    'MX',
    'Mexico',
    _la,
    ['MX', 'MEX'],
    ['mexico', 'mexican', 'mexicano', 'mexicanos'],
  ),
  Country(
    'AR',
    'Argentina',
    _la,
    ['ARG'],
    ['argentina', 'argentino', 'argentinos'],
  ),
  Country(
    'CO',
    'Colombia',
    _la,
    ['CO', 'COL'],
    ['colombia', 'colombiano', 'colombianos'],
  ),
  Country('CL', 'Chile', _la, ['CL'], ['chile', 'chileno', 'chilenos']),
  Country('PE', 'Peru', _la, ['PE', 'PER'], ['peru', 'peruano', 'peruanos']),
  Country(
    'VE',
    'Venezuela',
    _la,
    ['VE', 'VEN'],
    ['venezuela', 'venezolano', 'venezolanos'],
  ),
  Country('EC', 'Ecuador', _la, ['EC', 'ECU'], ['ecuador', 'ecuatoriano']),
  Country('UY', 'Uruguay', _la, ['UY', 'URU'], ['uruguay', 'uruguayo']),
  Country('PY', 'Paraguay', _la, ['PY', 'PAR'], ['paraguay', 'paraguayo']),
  Country('BO', 'Bolivia', _la, ['BO', 'BOL'], ['bolivia', 'boliviano']),
  Country('CR', 'Costa Rica', _la, ['CR'], ['costa rica']),
  Country('PA', 'Panama', _la, ['PAN'], ['panama']),
  Country(
    'DO',
    'Dominican Republic',
    _la,
    ['DO', 'DOM', 'RD'],
    ['dominicana', 'republica dominicana', 'dominican'],
  ),
  Country('CU', 'Cuba', _la, ['CU', 'CUB'], ['cuba', 'cubano']),
  Country('PR', 'Puerto Rico', _la, ['PR'], ['puerto rico']),
  Country('GT', 'Guatemala', _la, ['GT', 'GUA'], ['guatemala']),
  Country('HN', 'Honduras', _la, ['HN', 'HON'], ['honduras']),
  Country('SV', 'El Salvador', _la, ['SV', 'SLV'], ['el salvador', 'salvador']),
  Country('NI', 'Nicaragua', _la, ['NI', 'NCA'], ['nicaragua']),
  Country(
    'BR',
    'Brazil',
    _la,
    ['BR', 'BRA'],
    ['brazil', 'brasil', 'brazilian', 'brasileiro'],
  ),
  Country(
    'LATAM',
    'Latin America (general)',
    _la,
    ['LATAM', 'LAT AM', 'LATINO'],
    [
      'latam',
      'latino',
      'latinos',
      'latina',
      'latin',
      'latinoamerica',
      'latin america',
      'hispano',
      'hispanic',
    ],
  ),
  // North America
  Country(
    'US',
    'United States',
    _na,
    ['US', 'USA'],
    ['usa', 'united states', 'estados unidos', 'american'],
  ),
  Country('CA', 'Canada', _na, ['CA', 'CAN'], ['canada', 'canadian']),
  // Middle East & Arabic
  Country(
    'ARABIC',
    'Arabic',
    _ar,
    ['AR', 'ARB', 'ARAB'],
    ['arabic', 'arab', 'arabe', 'arabes', 'arabia'],
  ),
  Country(
    'AE',
    'United Arab Emirates',
    _ar,
    ['AE', 'UAE'],
    ['emirates', 'uae', 'dubai'],
  ),
  Country(
    'MA',
    'Morocco',
    _ar,
    ['MA', 'MAR'],
    ['morocco', 'marruecos', 'maroc'],
  ),
  Country(
    'DZ',
    'Algeria',
    _ar,
    ['DZ', 'ALG'],
    ['algeria', 'argelia', 'algerie'],
  ),
  Country('TN', 'Tunisia', _ar, ['TN', 'TUN'], ['tunisia', 'tunez', 'tunisie']),
  Country('EG', 'Egypt', _ar, ['EG', 'EGY'], ['egypt', 'egipto']),
  Country('IL', 'Israel', _ar, ['IL', 'ISR'], ['israel']),
  Country('IR', 'Iran', _ar, ['IR', 'IRN'], ['iran', 'persian', 'farsi']),
  Country(
    'KU',
    'Kurdish',
    _ar,
    ['KU', 'KUR', 'KURD'],
    ['kurdish', 'kurdistan'],
  ),
  // Africa
  Country(
    'AFRICA',
    'Africa (general)',
    _af,
    ['AF', 'AFR'],
    ['africa', 'african', 'africa tv'],
  ),
  Country(
    'ZA',
    'South Africa',
    _af,
    ['ZA', 'RSA'],
    ['south africa', 'sudafrica'],
  ),
  Country('NG', 'Nigeria', _af, ['NG', 'NGA'], ['nigeria']),
  // Asia
  Country(
    'IN',
    'India',
    _as,
    ['IND'],
    ['india', 'indian', 'hindi', 'bollywood', 'tamil', 'telugu', 'punjabi'],
  ),
  Country('PK', 'Pakistan', _as, ['PK', 'PAK'], ['pakistan', 'urdu']),
  Country('BD', 'Bangladesh', _as, ['BD', 'BAN'], ['bangladesh', 'bangla']),
  Country('CN', 'China', _as, ['CN', 'CHN'], ['china', 'chinese']),
  Country('JP', 'Japan', _as, ['JP', 'JPN'], ['japan', 'japon', 'japanese']),
  Country(
    'KR',
    'South Korea',
    _as,
    ['KR', 'KOR'],
    ['korea', 'corea', 'korean'],
  ),
  Country(
    'PH',
    'Philippines',
    _as,
    ['PH', 'PHI'],
    ['philippines', 'filipinas', 'pinoy'],
  ),
  Country(
    'TH',
    'Thailand',
    _as,
    ['TH', 'THA'],
    ['thailand', 'tailandia', 'thai'],
  ),
  Country('VN', 'Vietnam', _as, ['VN', 'VIE'], ['vietnam', 'vietnamese']),
  Country('ID', 'Indonesia', _as, ['IDN'], ['indonesia']),
  Country('ASIA', 'Asia (general)', _as, ['ASIA'], ['asia', 'asian']),
  // Oceania
  Country('AU', 'Australia', _oc, ['AU', 'AUS'], ['australia', 'aussie']),
  Country('NZ', 'New Zealand', _oc, ['NZ'], ['new zealand', 'nueva zelanda']),
];

/// Codes that are accepted with just a space after them ("ES Deportes").
/// Other codes need an explicit separator ("IT|", "[NO]") to avoid mistaking
/// ordinary words for countries.
const Set<String> _spaceSeparatedCodes = {
  'ES',
  'MX',
  'UK',
  'US',
  'USA',
  'FR',
  'PT',
  'BR',
  'CO',
  'AR',
  'NL',
  'PL',
  'RO',
  'TR',
  'GR',
  'RU',
  'LATAM',
  'EXYU',
  'ARG',
  'ESP',
};

final Map<String, Country> _countryByCode = {
  for (final country in countries)
    for (final code in country.codes) code: country,
};

final RegExp _flagRegex = RegExp(r'[\u{1F1E6}-\u{1F1FF}]{2}', unicode: true);
final RegExp _leadingCode = RegExp(
  r'^[\s|\[\(\{#*★☆•\-]*([A-Za-z]{2,5}(?:-[A-Za-z]{2})?)(\s*[|:\]\)\}»›•\-]|\s+|$)',
);
final RegExp _bracketedCode = RegExp(r'[|\[\(]\s*([A-Za-z]{2,5})\s*[|\]\)]');
final RegExp _trailingCode = RegExp(
  r'[|:\-\(\[]\s*([A-Za-z]{2,5})\s*[\)\]]?\s*$',
);

Country? _fromFlag(String name) {
  final match = _flagRegex.firstMatch(name);
  if (match == null) return null;
  final code = String.fromCharCodes(
    match.group(0)!.runes.map((r) => r - 0x1F1E6 + 65),
  );
  return _countryByCode[code == 'GB' ? 'UK' : code];
}

Country? _fromCode(String rawCode, {required bool spaceOnly}) {
  final code = rawCode.toUpperCase().replaceAll('-', '');
  final country = _countryByCode[code] ?? _countryByCode[rawCode.toUpperCase()];
  if (country == null) return null;
  // Codes written in lowercase are almost always ordinary words.
  if (rawCode != rawCode.toUpperCase()) return null;
  if (spaceOnly && !_spaceSeparatedCodes.contains(code)) return null;
  return country;
}

/// Guesses the country of a category or channel name, e.g. "ES| DEPORTES",
/// "|MX| CINE", "🇫🇷 Sport", "SPAIN - MOVIES" or "Canales Latinos".
Country? detectCountry(String name) {
  final flag = _fromFlag(name);
  if (flag != null) return flag;

  final leading = _leadingCode.firstMatch(name);
  if (leading != null) {
    final separator = leading.group(2) ?? '';
    final spaceOnly = separator.trim().isEmpty && separator.isNotEmpty;
    final country = _fromCode(leading.group(1)!, spaceOnly: spaceOnly);
    if (country != null) return country;
  }
  for (final match in _bracketedCode.allMatches(name)) {
    final country = _fromCode(match.group(1)!, spaceOnly: false);
    if (country != null) return country;
  }
  final trailing = _trailingCode.firstMatch(name);
  if (trailing != null) {
    final country = _fromCode(trailing.group(1)!, spaceOnly: false);
    if (country != null) return country;
  }

  final normalized = normalizeName(name);
  Country? best;
  var bestLength = 0;
  for (final country in countries) {
    for (final countryName in country.names) {
      // Prefer the longest match: "south africa" over "africa".
      if (countryName.length > bestLength &&
          _containsWords(normalized, countryName)) {
        best = country;
        bestLength = countryName.length;
      }
    }
  }
  return best;
}
