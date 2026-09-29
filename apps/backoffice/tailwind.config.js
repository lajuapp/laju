/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#E5FBF4',   // AppColors.primaryLight
          100: '#C3F7E5',
          200: '#90EED0',
          300: '#54E2B7',
          400: '#22D5A4',
          500: '#00C896',  // AppColors.primary (LAJU Mint/Teal)
          600: '#00A87E',
          700: '#008C69',
          800: '#006E53',
          900: '#052C28',  // AppColors dark forest
        },
        laju: {
          primary: '#00C896',
          primaryDark: '#009F75',
          primaryLight: '#E5FBF4',
          darkBg: '#0B1015',
          darkSurface: '#131B22',
          darkElevated: '#1D2733',
          darkBorder: '#263342',
          lightBg: '#F8F9FA',
          cyan: '#00B4D8',
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif'],
        mono: ['JetBrains Mono', 'Menlo', 'Monaco', 'Courier New', 'monospace'],
      }
    },
  },
  plugins: [],
}
