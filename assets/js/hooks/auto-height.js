export default {
  mounted() {
    const { el } = this;
    el.setAttribute("style", `height:${el.scrollHeight}px;overflow-y:hidden;`);

    el.addEventListener("input", () => {
      el.style.height = "auto";
      el.style.height = `${el.scrollHeight}px`;
    }, false);
  },
};

