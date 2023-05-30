export default {
  mounted() {
    setTimeout(() => {
      this.el.scrollIntoViewIfNeeded(false);
    }, 100);  },
};
