import { Modal } from './shared';

export default {
  mounted() {
    const { el } = this;
    const content = el.querySelector('.toggle-content');

    function onOpen() {
      content.classList.remove('hidden');
    }

    function onClose() {
      content.classList.add('hidden');
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
