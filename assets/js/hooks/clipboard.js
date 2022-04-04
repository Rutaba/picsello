import Clipboard from 'clipboard';
import { createPopper } from '@popperjs/core';

export default {
  mounted() {
    this.clipboard = new Clipboard(this.el);
    this.clipboard.on('success', () => {
      const tooltip = this.el.querySelector('[role="tooltip"]');
      this.popper = createPopper(this.el, tooltip);
      tooltip.classList.remove('hidden');
      this.el.classList.add(
        this?.el?.dataset?.clipboardBg
          ? this.el.dataset.clipboardBg
          : 'bg-green-finances-100'
      );

      setTimeout(() => {
        this.el.classList.remove(
          this?.el?.dataset?.clipboardBg
            ? this.el.dataset.clipboardBg
            : 'bg-green-finances-100'
        );
      }, 300);

      setTimeout(() => {
        tooltip.classList.add('hidden');
        this.popper.destroy();
      }, 2000);
    });
  },
  destroyed() {
    this.clipboard.destroy();
    this.popper?.destroy();
  },
};
