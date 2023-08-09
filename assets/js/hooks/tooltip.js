import tippy from 'tippy.js';

export default {
  mounted() {
    tippy(`#${this.el.id}`, {
      content: this.el.dataset.hint,
    });
  },
  updated() {
    console.log(this.el.id);
    tippy(`#${this.id}`, {
      content: this.el.dataset.hint,
    });
  },
};
