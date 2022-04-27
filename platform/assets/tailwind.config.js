let colors = require("tailwindcss/colors")

module.exports = {
  content: [
    './js/**/*.js',
    '../lib/*_web/**/*.*ex'
  ],
  theme: {
    extend: {
      colors: {
        neutral: colors.gray,
        positive: colors.green,
        urge: colors.blue,
        warning: colors.yellow,
        info: colors.blue,
        critical: colors.red,
      },
    },
    fontFamily: {
      'sans': ['Inter', 'system-ui', 'sans-serif'],
      'mono': ['Iosevka', 'monospace'],
    }
  },
  variants: {},
  plugins: [
    require('@tailwindcss/forms'),
    require('a17t'),
  ]
};