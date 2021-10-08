const defaultTheme = require('tailwindcss/defaultTheme');
const plugin = require('tailwindcss/plugin');
const svgToDataUri = require('mini-svg-data-uri');

const safelist = ['border', 'text', 'bg']
  .map((pre) =>
    ['red-sales-300', 'purple-marketing-300', 'orange-inbox-300', 'blue-planning-300']
      .map((c) => [pre, c].join('-'))
  )
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
        base: {
          300: '#1F1C1E',
          250: '#898989',
          200: '#EFEFEF',
          100: '#FFFFFF',
        },
        'blue-gallery': {
          300: '#6696F8',
          200: '#92B6F9',
          100: '#E1EBFD',
        },
        'red-sales': { 300: '#E1662F', 200: '#EF8F83', 100: '#FDF2F2' },
        'blue-planning': { 300: '#4DAAC6', 200: '#86C3CC', 100: '#F2FDFB' },
        'yellow-files': { 300: '#F7CB45', 200: '#FAE46B', 100: '#FEF9E2' },
        'purple-marketing': { 300: '#585DF6', 200: '#7F82E6', 100: '#F8F4FE' },
        'orange-inbox': { 300: '#F19D4A', 200: '#F5BD7F', 100: '#FDF4E9' },
        'green-finances': { 300: '#429467', 200: '#81CF67', 100: '#CFE7CD' },
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
