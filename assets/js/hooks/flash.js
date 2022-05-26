export default {
  mounted() {
    setTimeout(() => {
      this.pushEvent('lv:clear-flash', { key: this.el.dataset.phxValueKey });
    }, 5000);
  },
};
