import IMask from 'imask';

export default {
  mounted() {
    IMask(this.el, {
      mask: '$num',
      blocks: {
        num: {
          mask: Number,
          thousandsSeparator: ',',
          scale: 2,
          padFractionalZeros: true,
          radix: '.'
        }
      }
    });
  },
};

