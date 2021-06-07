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
      }
    },
  },
  variants: {
    extend: {},
  },
  plugins: [],
}
