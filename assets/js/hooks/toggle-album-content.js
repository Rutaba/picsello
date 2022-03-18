import { Modal } from './shared';

export default {
  mounted() {
    const { el } = this;
    const content = el.querySelector('.toggle-content');

    console.log("here")
    function onOpen() {
      console.log("here")
      content.classList.add('hidden');
      // content.classList.remove('hidden');
    }

    function onClose() {
      content.classList.remove('hidden');
      // content.classList.remove('hidden');
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
