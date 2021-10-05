const defaultTheme = require('tailwindcss/defaultTheme');
const plugin = require('tailwindcss/plugin');
const svgToDataUri = require('mini-svg-data-uri');

const dynamicColors = {
  'blue-primary': '#4DAAC6',
  'orange-dashboard-inbox': '#F19D4A',
  'orange-warning': '#E1662F',
  'purple-dashboard-marketing': '#585DF6',
};

const safelist = ['border', 'text', 'bg']
  .map((pre) => Object.keys(dynamicColors).map((c) => [pre, c].join('-')))
  .flat();

module.exports = {
  mode: 'jit',
  purge: {
    content: [
      '../**/*.html.eex',
      '../**/*.html.leex',
      '../**/*.html.heex',
      '../**/views/**/*.ex',
      '../**/live/**/*.ex',
      './js/**/*.js',
    ],
    safelist,
  },
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {
      colors: {
        ...dynamicColors,
        black: '#231F20',
        'blue-light-primary': '#F2FDFB',
        'blue-onboarding-first': '#86C3CC',
        'blue-onboarding-fourth': '#92B6F9',
        'blue-secondary': '#86C3CC',
        'gray-disabled': '#AAA',
        green: '#429467',
        'green-light': '#CFE7CD',
        'green-onboarding-third': '#CFE7CD',
        orange: '#FFBA74',
        'orange-onboarding-second': '#F5BD7F',
        'red-invalid': '#CB0000',
        'red-invalid-bg': '#FFF2F2',
      },
      fontFamily: {
        sans: ['Be Vietnam', ...defaultTheme.fontFamily.sans],
      },
      spacing: {
        '90vw': '90vw',
        '85vh': '85vh',
        '5vw': '5vw',
      },
      fontSize: {
        '13px': '13px',
        '16px': '16px',
      },
      zIndex: { '-10': '-10' },
    },
  },
  variants: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/forms')({
      strategy: 'class',
    }),
    plugin(({ addBase }) => {
      addBase({
        '.form-checkbox:checked': {
          backgroundSize: '65% 65%',
          backgroundImage: `url("${svgToDataUri(
            `<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M1 8.22222L6.15789 14L15 1" stroke="white" stroke-linecap="round" stroke-linejoin="round"/>
</svg>`
          )}")`,
        },
      });
    }),
  ],
};
