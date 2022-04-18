import { Modal } from './shared';

export default {
  mounted() {
    const { el } = this;
    const e = el.querySelector('.toggle-it')
    function onClose() {
      if (e.classList.contains('item-border')) {
        e.classList.remove('item-border');
      } else {
        e.classList.add('item-border');
      }
    }

    const isClosed = () => {e.classList.contains('item-border');}
    function onOpen() {e.classList.contains('item-border');}

    this.modal = Modal({ el, onOpen, onClose, isClosed });
  },

  destroyed() {
    this.modal.destroyed();
  },

  updated() {
    this.modal.updated();
  },
};
