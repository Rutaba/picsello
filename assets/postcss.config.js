module.exports = {
  plugins: {
    'postcss-custom-properties': {
      preserve: false, // completely reduce all css vars
      importFrom: [
        'css/components/calendar.css',
        'css/components/date-picker.css',
      ],
    },
    'postcss-import': {},
    tailwindcss: {},
    autoprefixer: {},
  },
};
