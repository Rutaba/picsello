export default {
  mounted() {
    const { el } = this;
    el.setAttribute("style", `height:${el.scrollHeight}px;`);

    el.addEventListener("input", () => {
      el.style.height = "auto";
      el.style.height = `${el.scrollHeight}px`;
    }, false);
  },
};

