import IMask from 'imask';

function percentMask(el) {
  return IMask(el, {
    mask: 'num%',
    lazy: false,
    blocks: {
      num: {
        mask: Number,
        max: 1000,
        min: 0,
        normalizeZeros: true,
        scale: 2,
        signed: false,
        radix: '.',
      },
    },
  });
}

export default {
  mounted() {
    this.mask = percentMask(this.el);
  },
  updated() {
    this.mask?.destroy();
    this.mask = percentMask(this.el);
  },
  destroyed() {
    this.mask?.destroy();
  },
};
