const defaultTheme = require('tailwindcss/defaultTheme');
const plugin = require('tailwindcss/plugin');
const svgToDataUri = require('mini-svg-data-uri');

module.exports = {
  mode: 'jit',
  purge: [
    "../**/*.html.eex",
    "../**/*.html.leex",
    "../**/*.html.heex",
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
        'blue-onboarding-fourth': '#92B6F9',
        black: '#231F20',
        'red-invalid': '#CB0000',
        'red-invalid-bg': '#FFF2F2',
        'gray-disabled': '#AAA',
        'green': '#429467',
        'green-light': '#CFE7CD',
        'green-onboarding-third': '#CFE7CD',
        'orange': '#FFBA74',
        'orange-onboarding-second': '#F5BD7F',
        'orange-warning': '#E1662F',
        'blue-onboarding-first': '#86C3CC'
      },
      fontFamily: {
        sans: ['Be Vietnam', ...defaultTheme.fontFamily.sans],
      },
      spacing: {
        '90vw': '90vw',
        '85vh': '85vh',
        '5vw': '5vw'
      },
      zIndex: {'-10':'-10'}
    },
  },
  variants: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/aspect-ratio'),
    require("@tailwindcss/forms")({
      strategy: 'class',
    }),
    plugin(({addBase}) => {
      addBase({
        '.form-checkbox:checked':
        {
          backgroundSize: '65% 65%',
          backgroundImage: `url("${svgToDataUri(
`<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M1 8.22222L6.15789 14L15 1" stroke="white" stroke-linecap="round" stroke-linejoin="round"/>
</svg>`
          )}")`,
        }
      })
    })
  ],
}
