export default {
  mounted() {
    const dataset = this.el.dataset
    this.el.addEventListener('click', () => {
      const el = document.getElementById(dataset.resultId)
      el.checked = true
      this.pushEventTo(dataset.target, "change", { "_target": ["selection"], "selection": el.value })
    })
  }
};