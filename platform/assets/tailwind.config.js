let colors = require("tailwindcss/colors")

module.exports = {
  content: [
    './js/**/*.js',
    '../lib/*_web/**/*.*ex'
  ],
  theme: {
    extend: {
      colors: {
        neutral: colors.slate,
        positive: colors.green,
        urge: colors.violet,
        warning: colors.yellow,
        info: colors.blue,
        critical: colors.red,
      },
    },
  },
  variants: {},
  plugins: [
    require('@tailwindcss/forms'),
    require('a17t'),
  ]
};