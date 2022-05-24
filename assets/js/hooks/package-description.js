export default {
  mounted() {
    const el = this.el;
    const tooltip = el.querySelector('[role="tooltip"]');

    el.querySelector('.view_more')?.addEventListener('mouseover', (e) => {
      tooltip.querySelector('.raw_html').innerHTML =
        el.querySelector('.raw_html_inline').innerHTML;
      tooltip.classList.remove('hidden');
    });

    el.addEventListener('mouseleave', () => {
      tooltip.classList.add('hidden');
    });
  },
  destroyed() {
    this.popper?.destroy();
  },
};
