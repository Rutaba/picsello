import { Modal } from './shared';

export default {
  mounted() {
    const { el } = this;
    const attr = '.' + el.getAttribute('target-class');
    const content = el.querySelectorAll(attr);

    function onClose() {
      content.forEach((e, i) => {
        if (e.classList.contains('hidden')) {
          e.classList.remove('hidden');
        }else{
          e.classList.add('hidden');
        }
      });
    }

    const isClosed = () => content.forEach((e, i) => {
      e.classList.contains('hidden');
    });

    this.modal = Modal({ el, onClose, isClosed });
  },

  destroyed() {
    this.modal.destroyed();
  },

  updated() {
    this.modal.updated();
  },
};
