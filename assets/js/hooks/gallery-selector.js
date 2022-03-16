import { Modal } from './shared';

export default {
  mounted() {
    const { el } = this;
    const e = el.querySelector('.toggle-it')
    function onClose() {
      if (e.classList.contains('photo-border')) {
        e.classList.remove('photo-border');
      } else {
        e.classList.add('photo-border');
      }
    }

    const isClosed = () => {e.classList.contains('photo-border');}
    function onOpen() {e.classList.contains('photo-border');}

    this.modal = Modal({ el, onOpen, onClose, isClosed });
  },

  destroyed() {
    this.modal.destroyed();
  },

  updated() {
    this.modal.updated();
  },
};
