export default {
  mounted() {
    var element = this.el;

    if (element.dataset.smooth) {
      var offsetPosition = element.getBoundingClientRect().top + window.pageYOffset - 70;

      setTimeout(() => {
        window.scrollTo({ top: offsetPosition, behavior: 'smooth' });
      }, 100);
    } else {
      setTimeout(() => {
        element.scrollIntoViewIfNeeded(false);
      }, 100);
    }
  },
};
