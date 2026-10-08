import id from '../../locales/id.json';
import en from '../../locales/en.json';
import ru from '../../locales/ru.json';
import ja from '../../locales/ja.json';
import zh from '../../locales/zh.json';

export type Locale = 'id' | 'en' | 'ru' | 'ja' | 'zh';

export interface LanguageOption {
  code: Locale;
  name: string;
  flag: string;
}

export const supportedLocales: LanguageOption[] = [
  { code: 'id', name: 'Indonesia', flag: '🇮🇩' },
  { code: 'en', name: 'English', flag: '🇬🇧' },
  { code: 'ru', name: 'Русский', flag: '🇷🇺' },
  { code: 'ja', name: '日本語', flag: '🇯🇵' },
  { code: 'zh', name: '简体中文', flag: '🇨🇳' },
];

export const translations = {
  id,
  en,
  ru,
  ja,
  zh,
};

export type TranslationKey = keyof typeof id;
