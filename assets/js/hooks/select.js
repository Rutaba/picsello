import { createPopper } from '@popperjs/core';
import { Modal } from './shared';

export default {
  mounted() {
    const { el } = this;
    const content = el.querySelector('.popover-content');
    const openIcon = el.querySelector('.open-icon');
    const closeIcon = el.querySelector('.close-icon');
    const {
      dataset: { offsetY },
    } = el;

    let popper;

    function onClose() {
      popper.destroy();
      content.classList.add('hidden');
      openIcon.classList.remove('hidden');
      closeIcon.classList.add('hidden');
    }

    function onOpen() {
      content.classList.remove('hidden');
      openIcon.classList.add('hidden');
      closeIcon.classList.remove('hidden');

      popper = createPopper(el, content, {
        placement: 'bottom-start',
        modifiers: [
          {
            name: 'offset',
            options: { offset: [0, parseInt(offsetY || "0")] },
          },
        ],
      });
    }

    const isClosed = () => content.classList.contains('hidden');

    this.modal = Modal({ onClose, onOpen, el, isClosed });
  },

  destroyed() {
    this.modal.destroyed();
  },

  updated() {
    this.modal.updated();
  },
};
