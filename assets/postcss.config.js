module.exports = {
  plugins: {
    'postcss-custom-properties': {
      preserve: false, // completely reduce all css vars
      importFrom: ['css/components/calendar.css'],
    },
    'postcss-import': {},
    tailwindcss: {},
    autoprefixer: {},
  },
};
