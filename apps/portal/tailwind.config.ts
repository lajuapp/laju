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
          50: '#E5FBF4',
          100: '#C3F7E5',
          200: '#8DF0CD',
          300: '#4DE4AE',
          400: '#1CD79A',
          500: '#00C896', // Brand Primary Mint/Teal
          600: '#00B384',
          700: '#009F75', // Brand Primary Dark
          800: '#007D5C',
          900: '#005942',
          950: '#003829',
          DEFAULT: '#00C896',
          dark: '#009F75',
          light: '#E5FBF4',
          bubble: '#D6F8EC',
          bubbleBorder: '#C0F0DF',
          glow: 'rgba(0, 200, 150, 0.25)',
        },
        dark: {
          bg: '#0B1015',
          surface: '#131B22',
          elevated: '#1D2733',
          border: '#263342',
        },
        brand: {
          50: '#E5FBF4',
          100: '#C3F7E5',
          200: '#8DF0CD',
          300: '#4DE4AE',
          400: '#1CD79A',
          500: '#00C896',
          600: '#00B384',
          700: '#009F75',
          800: '#007D5C',
          900: '#005942',
          950: '#003829',
        },
        pine: {
          800: '#009F75',
          900: '#005942',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif'],
        mono: ['JetBrains Mono', 'Menlo', 'Monaco', 'Courier New', 'monospace'],
      },
      boxShadow: {
        'mint-glow': '0 0 25px -5px rgba(0, 200, 150, 0.35)',
        'mint-glow-sm': '0 0 15px -3px rgba(0, 200, 150, 0.25)',
      },
    },
  },
  plugins: [],
};

export default config;
