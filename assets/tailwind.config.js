const defaultTheme = require('tailwindcss/defaultTheme');
const plugin = require('tailwindcss/plugin');
const svgToDataUri = require('mini-svg-data-uri');

const safelist = ['border', 'text', 'bg', 'hover:border']
  .map((pre) =>
    [
      'red-sales-300',
      'purple-marketing-300',
      'orange-inbox-300',
      'blue-planning-300',
    ].map((c) => [pre, c].join('-'))
  )
  .flat();

const combineValues = (values, prefix, cssProperty) =>
  Object.keys(values).reduce(
    (acc, key) => ({
      ...acc,
      ...(typeof values[key] === 'string'
        ? {
            [`${prefix}-${key}`]: {
              [cssProperty]: values[key],
            },
          }
        : combineValues(values[key], `${prefix}-${key}`, cssProperty)),
    }),
    {}
  );

module.exports = {
  mode: 'jit',
  content: [
    '../**/*.html.eex',
    '../**/*.html.leex',
    '../**/*.html.heex',
    '../**/views/**/*.ex',
    '../**/live/**/*.ex',
    './js/**/*.js',
  ],
  safelist,
  theme: {
    extend: {
      colors: {
        current: 'currentColor',
        gray: { 700: '#374151' },
        base: {
          350: '#231F20',
          300: '#1F1C1E',
          250: '#898989',
          225: '#C9C9C9',
          200: '#EFEFEF',
          100: '#FFFFFF',
        },
        toggle: { 100: '#50ACC4' },
        'blue-gallery': {
          400: '#4DAAC6',
          300: '#6696F8',
          200: '#92B6F9',
          100: '#E1EBFD',
        },
        'red-sales': { 300: '#E1662F', 200: '#EF8F83', 100: '#FDF2F2' },
        'blue-planning': { 300: '#4DAAC6', 200: '#86C3CC', 100: '#F2FDFB' },
        'yellow-files': { 300: '#F7CB45', 200: '#FAE46B', 100: '#FEF9E2' },
        'purple-marketing': { 300: '#585DF6', 200: '#7F82E6', 100: '#F8F4FE' },
        'orange-inbox': {
          400: '#FCF0EA',
          300: '#F19D4A',
          200: '#F5BD7F',
          100: '#FDF4E9',
        },
        'green-finances': { 300: '#429467', 200: '#81CF67', 100: '#CFE7CD' },
        'red-error': { 300: '#F60000' },
      },
      fontFamily: {
        sans: ['Be Vietnam', ...defaultTheme.fontFamily.sans],
        client: ['"Avenir LT Std"'],
      },
      spacing: {
        '5vw': '5vw',
      },
      fontSize: {
        '13px': '13px',
        '16px': '16px',
        '15px': '15px',
      },
      boxShadow: {
        md: '0px 4px 4px 0px rgba(0, 0, 0, 0.25)',
        lg: '0px 4px 14px 0px rgba(0, 0, 0, 0.15)',
        xl: '0px 14px 14px 0px rgba(0, 0, 0, 0.20)',
        top: '0px -14px 34px rgba(0, 0, 0, 0.15)',
      },
      zIndex: { '-10': '-10' },
      strokeWidth: { 3: '3', 4: '4' },
      gridTemplateColumns: {
        cart: '110px minmax(80px, 1fr) auto',
        cartWide: '16rem 1fr auto',
      },
      gridTemplateRows: {
        preview: '50px auto',
      },
    },
  },
  plugins: [
    require('@tailwindcss/line-clamp'),
    require('@tailwindcss/forms')({
      strategy: 'class',
    }),
    plugin(({ addUtilities, theme }) => {
      addUtilities(
        combineValues(
          theme('colors'),
          '.text-decoration',
          'textDecorationColor'
        )
      );
    }),
    plugin(({ addUtilities, theme }) => {
      addUtilities(
        combineValues(
          theme('spacing'),
          '.underline-offset',
          'textUnderlineOffset'
        )
      );
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
