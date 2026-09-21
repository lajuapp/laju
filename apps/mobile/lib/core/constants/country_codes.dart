class CountryItem {
  final String nameKey;
  final String dialCode;
  final String flag;
  final String code;

  const CountryItem({
    required this.nameKey,
    required this.dialCode,
    required this.flag,
    required this.code,
  });
}

class CountryCodes {
  CountryCodes._();

  static const List<CountryItem> all = [
    CountryItem(nameKey: 'country_id', dialCode: '+62', flag: '🇮🇩', code: 'ID'),
    CountryItem(nameKey: 'country_us', dialCode: '+1', flag: '🇺🇸', code: 'US'),
    CountryItem(nameKey: 'country_gb', dialCode: '+44', flag: '🇬🇧', code: 'GB'),
    CountryItem(nameKey: 'country_sg', dialCode: '+65', flag: '🇸🇬', code: 'SG'),
    CountryItem(nameKey: 'country_my', dialCode: '+60', flag: '🇲🇾', code: 'MY'),
    CountryItem(nameKey: 'country_ru', dialCode: '+7', flag: '🇷🇺', code: 'RU'),
    CountryItem(nameKey: 'country_cn', dialCode: '+86', flag: '🇨🇳', code: 'CN'),
    CountryItem(nameKey: 'country_jp', dialCode: '+81', flag: '🇯🇵', code: 'JP'),
    CountryItem(nameKey: 'country_de', dialCode: '+49', flag: '🇩🇪', code: 'DE'),
    CountryItem(nameKey: 'country_fr', dialCode: '+33', flag: '🇫🇷', code: 'FR'),
    CountryItem(nameKey: 'country_au', dialCode: '+61', flag: '🇦🇺', code: 'AU'),
    CountryItem(nameKey: 'country_sa', dialCode: '+966', flag: '🇸🇦', code: 'SA'),
    CountryItem(nameKey: 'country_in', dialCode: '+91', flag: '🇮🇳', code: 'IN'),
    CountryItem(nameKey: 'country_kr', dialCode: '+82', flag: '🇰🇷', code: 'KR'),
    CountryItem(nameKey: 'country_ae', dialCode: '+971', flag: '🇦🇪', code: 'AE'),
    CountryItem(nameKey: 'country_tr', dialCode: '+90', flag: '🇹🇷', code: 'TR'),
    CountryItem(nameKey: 'country_br', dialCode: '+55', flag: '🇧🇷', code: 'BR'),
    CountryItem(nameKey: 'country_th', dialCode: '+66', flag: '🇹🇭', code: 'TH'),
    CountryItem(nameKey: 'country_vn', dialCode: '+84', flag: '🇻🇳', code: 'VN'),
    CountryItem(nameKey: 'country_ph', dialCode: '+63', flag: '🇵🇭', code: 'PH'),
  ];

  static CountryItem getDefaultForLocale(String languageCode) {
    switch (languageCode) {
      case 'id':
        return all.firstWhere((c) => c.code == 'ID');
      case 'ru':
        return all.firstWhere((c) => c.code == 'RU');
      case 'zh':
        return all.firstWhere((c) => c.code == 'CN');
      case 'ja':
        return all.firstWhere((c) => c.code == 'JP');
      case 'en':
      default:
        return all.firstWhere((c) => c.code == 'ID'); // default ID or US
    }
  }
}
