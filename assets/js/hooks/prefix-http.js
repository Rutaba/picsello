export default {
  mounted() {
    this.el.addEventListener('change', () => {
      const { value } = this.el;
      if (value && !value.match(/^https?:\/\//)) {
        this.el.value = `https://${value}`;
      }
    });
  },
};
