import { createPopper } from '@popperjs/core';

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

    function clickOutside(e) {
      const isOutside = e.target.closest(`#${el.id}`) === null;

      if (isOutside) {
        close();
      }
    }

    this.removeClickOutside = () => {
      document.body.removeEventListener('click', clickOutside);
    };

    const close = () => {
      popper.destroy();
      content.classList.add('hidden');
      changeArrowTo('down');
      this.removeClickOutside();
    };

    const open = () => {
      content.classList.remove('hidden');
      changeArrowTo('up');

      popper = createPopper(el, content, {
        modifiers: [{ name: 'offset', options: { offset: [10, 10] } }],
      });

      document.body.addEventListener('click', clickOutside);
    };

    this.isClosed = () => content.classList.contains('hidden');

    el.addEventListener('click', () => {
      if (this.isClosed()) {
        open();
      } else {
        close();
      }
    });
  },

  destroyed() {
    this.removeClickOutside();
  },

  updated() {
    if (this.isClosed()) {
      this.removeClickOutside();
    }
  },
};
