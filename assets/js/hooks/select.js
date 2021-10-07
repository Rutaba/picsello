import { createPopper } from '@popperjs/core';
import { Modal } from './shared';

export default {
  mounted() {
    const { el } = this;
    const content = el.querySelector('.popover-content');
    let popper;

    function changeArrowTo(direction) {
      const arrow = el.querySelector(`#${el.id} > svg > use`);
      const href = arrow.getAttribute('xlink:href');

      arrow.setAttribute('xlink:href', href.replace(/#.+$/, `#${direction}`));
    }

    function onClose() {
      popper.destroy();
      content.classList.add('hidden');
      changeArrowTo('down');
    }

    function onOpen() {
      content.classList.remove('hidden');
      changeArrowTo('up');

      popper = createPopper(el, content, {
        modifiers: [{ name: 'offset', options: { offset: [10, 10] } }],
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
