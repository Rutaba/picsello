import { Modal } from './shared';

export default {
  mounted() {
    const { el } = this;
    const content = el.querySelector('.toggle-content');
    const openIcon = el.querySelector('.open-icon');
    const closeIcon = el.querySelector('.close-icon');

    function onOpen() {
      content.classList.remove('hidden');
      openIcon.classList.add('hidden');
      closeIcon.classList.remove('hidden');
    }

    function onClose() {
      content.classList.add('hidden');
      openIcon.classList.remove('hidden');
      closeIcon.classList.add('hidden');
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
