import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#F0FDF4',
          100: '#DCFCE7',
          200: '#BBF7D0',
          300: '#86EFAC',
          400: '#4ADE80',
          500: '#22C55E',
          600: '#16A34A',
          700: '#15803D',
          800: '#166534',
          900: '#14532D',
          950: '#052E16',
        },
        pine: {
          50: '#F4F8F6',
          100: '#E5EFEA',
          200: '#C7DED5',
          300: '#9DBEB3',
          400: '#5C9683',
          500: '#2D6B58',
          600: '#1A5343',
          700: '#134638',
          800: '#0D382C', // Primary button color from screenshot
          900: '#08281F',
          950: '#041812',
        },
        warm: {
          50: '#FAF9F6',
          100: '#F5F4EF', // Page background from screenshot
          200: '#EAE8DE',
          300: '#DBD8CA',
          400: '#BFBBA9',
          500: '#9C9885',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif'],
        mono: ['JetBrains Mono', 'Menlo', 'Monaco', 'Courier New', 'monospace'],
      },
    },
  },
  plugins: [],
};

export default config;
