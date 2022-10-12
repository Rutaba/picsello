import Clipboard from 'clipboard';
import { createPopper } from '@popperjs/core';

export default {
  mounted() {
    this.handleEvent('CopyToClipboard', ({ url: url }) => {
      navigator.clipboard.writeText(url);
    });

    this.clipboard = new Clipboard(this.el);
    this.clipboard.on('success', () => {
      const tooltip = this.el.querySelector('[role="tooltip"]');
      const clipboardBg = this?.el?.dataset?.clipboardBg;
      this.popper = createPopper(this.el, tooltip);
      tooltip.classList.remove('hidden');
      this.el.classList.add(
        clipboardBg ? clipboardBg : 'bg-green-finances-100'
      );

      setTimeout(() => {
        this.el.classList.remove(
          clipboardBg ? clipboardBg : 'bg-green-finances-100'
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
