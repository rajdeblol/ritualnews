/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './lib/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        paper: '#F5F0E8',
        ink: '#1C1A17',
        muted: '#8C8478',
        border: '#D9D2C4',
        card: '#EDEAE2',
        card2: '#E5E1D8',
        bull: '#2D6A4F',
        bear: '#9B2335',
        neutral: '#6B7280',
        amber: '#B8860B',
      },
      fontFamily: {
        mono: ['JetBrains Mono', 'monospace'],
        sans: ['Inter', 'sans-serif'],
      },
      boxShadow: {
        terminal: '0 1px 0 0 #d9d2c4, 0 8px 24px rgba(28, 26, 23, 0.06)',
      },
    },
  },
  plugins: [],
};
