/// Helper for bilingual country display names (Arabic / English) and smart normalized search.
class CountryNames {
  CountryNames._();

  static const Map<String, String> _arabicByIso = {
    'AD': 'أندورا',
    'AE': 'الإمارات العربية المتحدة',
    'AF': 'أفغانستان',
    'AG': 'أنتيغوا وبربودا',
    'AI': 'أنغويلا',
    'AL': 'ألبانيا',
    'AM': 'أرمينيا',
    'AO': 'أنغولا',
    'AQ': 'القارة القطبية الجنوبية',
    'AR': 'الأرجنتين',
    'AS': 'ساموا الأمريكية',
    'AT': 'النمسا',
    'AU': 'أستراليا',
    'AW': 'أروبا',
    'AZ': 'أذربيجان',
    'BA': 'البوسنة والهرسك',
    'BB': 'بربادوس',
    'BD': 'بنغلاديش',
    'BE': 'بلجيكا',
    'BF': 'بوركينا فاسو',
    'BG': 'بلغاريا',
    'BH': 'البحرين',
    'BI': 'بوروندي',
    'BJ': 'بنين',
    'BM': 'برمودا',
    'BN': 'بروناي',
    'BO': 'بوليفيا',
    'BQ': 'بونير',
    'BR': 'البرازيل',
    'BS': 'جزر البهاما',
    'BT': 'بوتان',
    'BW': 'بوتسوانا',
    'BY': 'بيلاروسيا',
    'BZ': 'بليز',
    'CA': 'كندا',
    'CC': 'جزر كوكوس',
    'CD': 'جمهورية الكونغو الديمقراطية',
    'CF': 'جمهورية أفريقيا الوسطى',
    'CG': 'الكونغو',
    'CH': 'سويسرا',
    'CI': 'ساحل العاج',
    'CL': 'تشيلي',
    'CM': 'الكاميرون',
    'CN': 'الصين',
    'CO': 'كولومبيا',
    'CR': 'كوستاريكا',
    'CU': 'كوبا',
    'CV': 'الرأس الأخضر',
    'CW': 'كوراساو',
    'CX': 'جزيرة الكريسماس',
    'CY': 'قبرص',
    'CZ': 'التشيك',
    'DE': 'ألمانيا',
    'DK': 'الدنمارك',
    'DM': 'دومينيكا',
    'DO': 'جمهورية الدومينيكان',
    'DZ': 'الجزائر',
    'EC': 'الإكوادور',
    'EE': 'إستونيا',
    'EG': 'مصر',
    'ER': 'إريتريا',
    'ES': 'إسبانيا',
    'ET': 'إثيوبيا',
    'FI': 'فنلندا',
    'FJ': 'فيجي',
    'FK': 'جزر فوكلاند',
    'FO': 'جزر فارو',
    'FR': 'فرنسا',
    'GA': 'الغابون',
    'GB': 'المملكة المتحدة (بريطانيا)',
    'GD': 'غرينادا',
    'GE': 'جورجيا',
    'GF': 'غويانا الفرنسية',
    'GG': 'غيرنزي',
    'GH': 'غانا',
    'GI': 'جبل طارق',
    'GL': 'غرينلاند',
    'GN': 'غينيا',
    'GP': 'غوادلوب',
    'GR': 'اليونان',
    'GT': 'غواتيمالا',
    'GU': 'غوام',
    'GW': 'غينيا بيساو',
    'GY': 'غيانا',
    'HK': 'هونغ كونغ',
    'HN': 'هندوراس',
    'HR': 'كرواتيا',
    'HT': 'هايتي',
    'HU': 'المجر',
    'ID': 'إندونيسيا',
    'IE': 'أيرلندا',
    'IL': 'إسرائيل',
    'IM': 'جزيرة مان',
    'IN': 'الهند',
    'IO': 'إقليم المحيط الهندي البريطاني',
    'IQ': 'العراق',
    'IR': 'إيران',
    'IS': 'آيسلندا',
    'IT': 'إيطاليا',
    'JE': 'جيرزي',
    'JM': 'جامايكا',
    'JO': 'الأردن',
    'JP': 'اليابان',
    'KE': 'كينيا',
    'KG': 'قيرغيزستان',
    'KH': 'كمبوديا',
    'KI': 'كيريباتي',
    'KM': 'جزر القمر',
    'KN': 'سانت كيتس ونيفيس',
    'KP': 'كوريا الشمالية',
    'KR': 'كوريا الجنوبية',
    'KW': 'الكويت',
    'KY': 'جزر كايمان',
    'KZ': 'كازاخستان',
    'LA': 'لاوس',
    'LB': 'لبنان',
    'LC': 'سانت لوسيا',
    'LI': 'ليختنشتاين',
    'LK': 'سريلانكا',
    'LR': 'ليبيريا',
    'LS': 'ليسوتو',
    'LT': 'ليتوانيا',
    'LU': 'لوكسمبورغ',
    'LV': 'لاتفيا',
    'LY': 'ليبيا',
    'MA': 'المغرب',
    'MC': 'موناكو',
    'MD': 'مولدوفا',
    'ME': 'الجبل الأسود',
    'MG': 'مدغشقر',
    'MH': 'جزر مارشال',
    'MK': 'مقدونيا الشمالية',
    'ML': 'مالي',
    'MM': 'ميانمار',
    'MN': 'منغوليا',
    'MO': 'ماكاو',
    'MQ': 'مارتينيك',
    'MS': 'مونتسرات',
    'MT': 'مالطا',
    'MU': 'موريشيوس',
    'MV': 'المالديف',
    'MW': 'مالاوي',
    'MX': 'المكسيك',
    'MY': 'ماليزيا',
    'MZ': 'موزمبيق',
    'NA': 'ناميبيا',
    'NC': 'كاليدونيا الجديدة',
    'NE': 'النيجر',
    'NG': 'نيجيريا',
    'NI': 'نيكاراغوا',
    'NL': 'هولندا',
    'NO': 'النرويج',
    'NP': 'نيبال',
    'NU': 'نيوي',
    'NZ': 'نيوزيلندا',
    'OM': 'عُمان',
    'PA': 'بنما',
    'PE': 'بيرو',
    'PF': 'بولينيزيا الفرنسية',
    'PG': 'بابوا غينيا الجديدة',
    'PH': 'الفلبين',
    'PK': 'باكستان',
    'PL': 'بولندا',
    'PM': 'سان بيير وميكلون',
    'PR': 'بورتوريكو',
    'PS': 'فلسطين',
    'PT': 'البرتغال',
    'PW': 'بالاو',
    'PY': 'باراغواي',
    'QA': 'قطر',
    'RE': 'ريونيون',
    'RO': 'رومانيا',
    'RS': 'صربيا',
    'RU': 'روسيا',
    'RW': 'رواندا',
    'SA': 'السعودية',
    'SC': 'سيشل',
    'SD': 'السودان',
    'SE': 'السويد',
    'SG': 'سنغافورة',
    'SH': 'سانت هيلينا',
    'SI': 'سلوفينيا',
    'SK': 'سلوفاكيا',
    'SL': 'سيراليون',
    'SM': 'سان مارينو',
    'SN': 'السنغال',
    'SO': 'الصومال',
    'SR': 'سورينام',
    'SS': 'جنوب السودان',
    'SV': 'السلفادور',
    'SX': 'سينت مارتن',
    'SY': 'سوريا',
    'TD': 'تشاد',
    'TF': 'الأراضي الفرنسية الجنوبية',
    'TG': 'توغو',
    'TH': 'تايلاند',
    'TM': 'تركمانستان',
    'TN': 'تونس',
    'TO': 'تونغا',
    'TR': 'تركيا',
    'TT': 'ترينيداد وتوباغو',
    'TW': 'تايوان',
    'TZ': 'تنزانيا',
    'UA': 'أوكرانيا',
    'UG': 'أوغندا',
    'UM': 'جزر الولايات المتحدة الصغيرة النائية',
    'US': 'الولايات المتحدة الأمريكية',
    'UY': 'أوروغواي',
    'UZ': 'أوزبكستان',
    'VA': 'الفاتيكان',
    'VC': 'سانت فنسنت والغرينادين',
    'VE': 'فنزويلا',
    'VG': 'جزر العذراء البريطانية',
    'VI': 'جزر العذراء الأمريكية',
    'VN': 'فيتنام',
    'VU': 'فانواتو',
    'WF': 'واليس وفوتونا',
    'XK': 'كوسوفو',
    'YE': 'اليمن',
    'YT': 'مايوت',
    'ZA': 'جنوب أفريقيا',
    'ZM': 'زامبيا',
    'ZW': 'زيمبابوي',
  };

  static const Map<String, List<String>> _aliasesByIso = {
    'AE': ['الإمارات', 'دبي', 'أبوظبي', 'الشارقة', 'uae', 'emirates', 'dubai', 'the united arab emirates', 'united arab emirates'],
    'SA': ['المملكة العربية السعودية', 'السعوديه', 'الرياض', 'جدة', 'مكة', 'ksa', 'saudi arabia'],
    'US': ['أمريكا', 'امريكا', 'الولايات المتحدة', 'usa', 'america', 'united states', 'the united states of america'],
    'GB': ['بريطانيا', 'انجلترا', 'إنجلترا', 'المملكة المتحدة', 'لندن', 'uk', 'england', 'britain', 'london', 'the united kingdom of great britain and northern ireland', 'united kingdom'],
    'TR': ['تركيا', 'turkey', 'turkiye', 'türkiye'],
    'EG': ['مصر', 'القاهرة', 'الاسكندرية', 'egypt', 'ägypten', 'aegypten'],
    'IQ': ['العراق', 'بغداد', 'iraq'],
    'JO': ['الاردن', 'الأردن', 'عمان', 'jordan'],
    'SY': ['سوريا', 'سورية', 'دمشق', 'syria'],
    'PS': ['فلسطين', 'القدس', 'غزة', 'دولة فلسطين', 'palestine'],
    'LB': ['لبنان', 'بيروت', 'lebanon'],
    'KW': ['الكويت', 'kuwait'],
    'QA': ['قطر', 'الدوحة', 'qatar'],
    'BH': ['البحرين', 'المنامة', 'bahrain'],
    'OM': ['عمان', 'سلطنة عمان', 'مسقط', 'oman'],
    'YE': ['اليمن', 'صنعاء', 'عدن', 'yemen'],
    'DZ': ['الجزائر', 'algeria'],
    'MA': ['المغرب', 'الرباط', 'الدار البيضاء', 'morocco'],
    'TN': ['تونس', 'tunisia'],
    'LY': ['ليبيا', 'طرابلس', 'libya'],
    'SD': ['السودان', 'الخرطوم', 'sudan'],
    'SO': ['الصومال', 'مقديشو', 'somalia'],
    'KM': ['جزر القمر', 'comoros'],
    'DE': ['المانيا', 'ألمانيا', 'برلين', 'germany', 'deutschland'],
    'FR': ['فرنسا', 'باريس', 'france'],
    'ES': ['اسبانيا', 'إسبانيا', 'مدريد', 'spain'],
    'IT': ['ايطاليا', 'إيطاليا', 'روما', 'italy'],
    'RU': ['روسيا', 'موسكو', 'russia'],
    'CN': ['الصين', 'بكين', 'china'],
    'JP': ['اليابان', 'طوكيو', 'japan'],
    'KR': ['كوريا', 'كوريا الجنوبية', 'سيول', 'south korea', 'korea'],
    'KP': ['كوريا الشمالية', 'north korea'],
    'IN': ['الهند', 'india'],
    'PK': ['باكستان', 'pakistan'],
    'IR': ['ايران', 'إيران', 'طهران', 'iran'],
    'NL': ['هولندا', 'أمستردام', 'holland', 'netherlands'],
    'CH': ['سويسرا', 'switzerland'],
    'SE': ['السويد', 'sweden'],
    'NO': ['النرويج', 'norway'],
    'DK': ['الدنمارك', 'denmark'],
    'GR': ['اليونان', 'greece'],
    'PT': ['البرتغال', 'portugal'],
    'BR': ['البرازيل', 'brazil'],
    'AR': ['الأرجنتين', 'الارجنتين', 'argentina'],
    'CA': ['كندا', 'canada'],
    'AU': ['أستراليا', 'استراليا', 'australia'],
    'CI': ['كوت ديفوار', 'ساحل العاج', 'ivory coast'],
    'CZ': ['التشيك', 'جمهورية التشيك', 'czech republic', 'czechia'],
    'VA': ['الفاتيكان', 'vatican'],
    'ZA': ['جنوب افريقيا', 'جنوب أفريقيا', 'south africa'],
    'MY': ['ماليزيا', 'malaysia'],
    'ID': ['اندونيسيا', 'إندونيسيا', 'indonesia'],
    'TH': ['تايلاند', 'تايلند', 'thailand'],
    'UA': ['اوكرانيا', 'أوكرانيا', 'ukraine'],
    'PL': ['بولندا', 'poland'],
    'AT': ['النمسا', 'austria'],
    'BE': ['بلجيكا', 'belgium'],
  };

  /// Normalizes Arabic and Latin text for forgiving search matching.
  static String normalize(String input) {
    var text = input.trim().toLowerCase();
    // Strip Arabic diacritics and tatweel
    text = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '');
    // Normalize Arabic letter variants
    text = text
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
    // Normalize common Latin diacritics (e.g. Türkiye -> turkiye)
    const latinMap = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n', 'ş': 's', 'ğ': 'g',
    };
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      buffer.write(latinMap[ch] ?? ch);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? getArabicName(String? isoCode, [String? apiName]) {
    if (isoCode != null && isoCode.isNotEmpty) {
      final upper = isoCode.toUpperCase();
      if (_arabicByIso.containsKey(upper)) {
        return _arabicByIso[upper];
      }
    }
    if (apiName != null && apiName.isNotEmpty) {
      final lowerApi = apiName.toLowerCase();
      for (final entry in _aliasesByIso.entries) {
        if (entry.value.any((a) => a.toLowerCase() == lowerApi)) {
          return _arabicByIso[entry.key];
        }
      }
    }
    return null;
  }

  static String getDisplayName(String? isoCode, String apiName, String lang) {
    if (lang == 'ar') {
      final ar = getArabicName(isoCode, apiName);
      if (ar != null && ar.isNotEmpty) {
        return ar;
      }
    }
    return apiName;
  }

  /// Returns a match relevance score (0 = no match, 1 = contains, 2 = starts with / exact).
  static int matchScore(Map<String, dynamic> country, String rawQuery) {
    final query = normalize(rawQuery);
    if (query.isEmpty) return 1;

    final apiName = (country['name'] ?? '').toString();
    final iso = (country['iso_3166_1'] ?? '').toString().toUpperCase();

    final candidates = <String>[
      apiName,
      iso,
      if (_arabicByIso[iso] != null) _arabicByIso[iso]!,
      ...(_aliasesByIso[iso] ?? const []),
    ];

    int bestScore = 0;
    for (final candidate in candidates) {
      final normCandidate = normalize(candidate);
      if (normCandidate == query) return 3;
      if (normCandidate.startsWith(query)) {
        if (bestScore < 2) bestScore = 2;
      } else if (normCandidate.contains(query)) {
        if (bestScore < 1) bestScore = 1;
      } else if (normCandidate.startsWith('ال$query')) {
        // Handle searching without leading "ال" in Arabic (e.g. "سعودية" matching "السعودية")
        if (bestScore < 2) bestScore = 2;
      }
    }
    return bestScore;
  }
}
