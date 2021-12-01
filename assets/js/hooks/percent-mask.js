import IMask from 'imask';

function percentMask(el) {
  return IMask(el, {
    mask: 'num%',
    lazy: false,
    blocks: {
      num: {
        mask: Number,
        max: 9999,
        min: 0,
        normalizeZeros: true,
        scale: 2,
        signed: false,
        radix: '.',
        lazy: false,
      },
    },
  });
}

export default {
  mounted() {
    this.mask = percentMask(this.el);
    this.resetOnBlur = (_) => {
      if (this.el.classList.contains('text-input-invalid')) {
        this.mask.value = this.el.getAttribute('value');
        this.mask.updateValue();
        this.el.classList.remove('text-input-invalid');
      }
    };

    this.el.addEventListener('blur', this.resetOnBlur);
  },
  updated() {
    this.mask?.updateValue();
  },
  destroyed() {
    this.el.removeEventListener('blur', this.resetOnBlur);
    this.mask?.destroy();
  },
};
