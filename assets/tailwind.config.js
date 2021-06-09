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
        'primary-blue': '#00ADC9',
        'primary-blue-dark': '#0094B0',
        'invalid-red': '#CB0000',
        'invalid-bg-red': '#FFF2F2',
        'disabled-gray': '#AAA'
      }
    },
  },
  variants: {
    extend: {},
  },
  plugins: [],
}
