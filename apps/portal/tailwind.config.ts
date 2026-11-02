import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        laju: {
          50: '#EEF3EF',
          100: '#DCE8E0',
          200: '#C1D5C8',
          300: '#9BBBA8',
          400: '#6F987F',
          500: '#0D382C',
          600: '#134E3E',
          700: '#134E3E',
          800: '#0D382C',
          900: '#09291F',
          950: '#061B15',
          DEFAULT: '#0D382C',
          dark: '#134E3E',
          light: '#EEF3EF',
          bubble: '#E5EEE8',
          bubbleBorder: '#C1D5C8',
          glow: 'rgba(13, 56, 44, 0.16)',
        },
        dark: {
          bg: '#0B1015',
          surface: '#131B22',
          elevated: '#1D2733',
          border: '#263342',
        },
        brand: {
          50: '#EEF3EF',
          100: '#DCE8E0',
          200: '#C1D5C8',
          300: '#9BBBA8',
          400: '#6F987F',
          500: '#0D382C',
          600: '#134E3E',
          700: '#134E3E',
          800: '#0D382C',
          900: '#09291F',
          950: '#061B15',
        },
        pine: {
          700: '#134E3E',
          800: '#0D382C',
          900: '#09291F',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif'],
        mono: ['JetBrains Mono', 'Menlo', 'Monaco', 'Courier New', 'monospace'],
      },
      boxShadow: {
        'mint-glow': '0 8px 24px -8px rgba(13, 56, 44, 0.3)',
        'mint-glow-sm': '0 4px 14px -5px rgba(13, 56, 44, 0.24)',
      },
    },
  },
  plugins: [],
};

export default config;
