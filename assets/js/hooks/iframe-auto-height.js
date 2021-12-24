export default {
  mounted() {
    const { el } = this;

    el.onload = function () {
      el.height = `${el.contentWindow.document.body.scrollHeight}px`;
    };
  },
};
