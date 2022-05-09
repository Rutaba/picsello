import { createPopper } from '@popperjs/core';

const shouldAddHidden = (tooltip, add = true) =>
  add ? tooltip.classList.add('hidden') : tooltip.classList.remove('hidden');

export default {
  mounted() {
    const el = this.el;
    const tooltip = el.querySelector('[role="tooltip"]');
    this.popper = createPopper(el, tooltip);
    el.addEventListener('mouseover', () => shouldAddHidden(tooltip, false));
    el.addEventListener('mouseleave', () => shouldAddHidden(tooltip));
  },
  updated() {
    const el = this.el;
    const tooltip = el.querySelector('[role="tooltip"]');
    this.popper = createPopper(el, tooltip);
    el.addEventListener('mouseover', () => shouldAddHidden(tooltip, false));
    el.addEventListener('mouseleave', () => shouldAddHidden(tooltip));
  },
  destroyed() {
    this.popper?.destroy();
  },
};
