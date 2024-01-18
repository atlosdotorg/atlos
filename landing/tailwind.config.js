module.exports = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx}",
    "./components/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {},
    fontFamily: {
      'sans': ['Inter', 'system-ui', 'sans-serif'],
      'mono': ['Iosevka', 'monospace'],
    }
  },
  plugins: [
    require("a17t"),
    require('@tailwindcss/typography')
  ],
}
