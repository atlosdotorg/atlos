let colors = require("tailwindcss/colors")

module.exports = {
  content: [
    './js/**/*.js',
    '../lib/**/*.*ex'
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
      'mono': ["'Iosevka Web', mono, monospace", {
        fontVariationSettings: '"cv83" 2'
      }],
    }
  },
  variants: {},
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('a17t'),
  ]
};