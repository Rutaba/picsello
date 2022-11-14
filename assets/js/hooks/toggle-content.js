import { Modal } from './shared';

export default {
  mounted() {
    const { el } = this;
    const content = el.querySelector('.toggle-content');
    const icon = el.querySelector(`.${el.dataset.icon}`);

    function onOpen() {
      content.classList.remove('hidden');
      icon && icon.classList.add('rotate-180');
    }

    function onClose() {
      content.classList.add('hidden');
      icon && icon.classList.remove('rotate-180');
    }

    const isClosed = () => content.classList.contains('hidden');

    this.modal = Modal({ el, onOpen, onClose, isClosed });
  },

  destroyed() {
    this.modal.destroyed();
  },

  updated() {
    this.modal.updated();
  },
};
