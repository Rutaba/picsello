import tippy from 'tippy.js';

export default {
  mounted() {
    tippy(`#${this.el.id}`, {
      content: this.el.dataset.hint,
    });
  },
  updated() {
    tippy(`#${this.id}`, {
      content: this.el.dataset.hint,
    });
  },
};
