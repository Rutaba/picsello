import tippy from 'tippy.js';

export default {
  handleTippy() {
    tippy(`#${this.el.id}`, {
      content: this.el.dataset.hint,
      allowHTML: true,
      trigger: 'mouseenter click',
      interactive: true,
      placement: this.el.dataset.position || 'top',
    });
  },
  mounted() {
    this.handleTippy();
  },
  updated() {
    this.handleTippy();
  },
};
