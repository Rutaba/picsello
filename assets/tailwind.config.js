const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  mode: 'jit',
  purge: [
    "../**/*.html.eex",
    "../**/*.html.leex",
    "../**/views/**/*.ex",
    "../**/live/**/*.ex",
    "./js/**/*.js"
  ],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {
      colors: {
        'blue-primary': '#00ADC9',
        'blue-dark-primary': '#0094B0',
        'blue-light-primary': '#EFFDFB',
        black: '#231F20',
        'red-invalid': '#CB0000',
        'red-invalid-bg': '#FFF2F2',
        'gray-disabled': '#AAA',
        'green': '#65D157',
        'orange': '#FFBA74'
      },
      fontFamily: {
        sans: ['Be Vietnam', ...defaultTheme.fontFamily.sans],
      },
      zIndex: {'-10':'-10'}
    },
  },
  variants: {
    extend: {},
  },
  plugins: [
    require("@tailwindcss/forms")({
      strategy: 'class',
    }),
  ],
}
