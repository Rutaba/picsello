import IMask from 'imask';

function percentMask(el) {
  let maskOptions = {
    lazy: false,
    blocks: {
      num: {
        mask: Number,
        min: 0,
        normalizeZeros: true,
        scale: 2,
        signed: false,
        radix: '.',
        lazy: false,
      },
    },
  };

  if (el.dataset.includeSign === 'false') {
    maskOptions.mask = 'num';
    maskOptions.blocks.num.max = 100; // Set the custom max value for false
  } else {
    maskOptions.mask = 'num%';
    maskOptions.blocks.num.max = 9999; // Set the max value for percentage
  }

  return IMask(el, maskOptions);
}

export default {
  mounted() {
    const customValue = this.el.dataset.includeSign;
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
