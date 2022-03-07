import { Modal } from './shared';

export default {
  mounted() {
    const { el } = this;

    const attr = '.' + el.getAttribute('target-class');
    const content = el.querySelectorAll(attr);

    
    function onClose() {}

    function isClosed() {
      el.addEventListener('click', (e) => {
        content.forEach((element, i) => {
          element.classList.add('hidden');
        });      
        e.target.nextElementSibling.classList.remove('hidden')
      });
    }

    this.modal = Modal({el, onClose, isClosed});
  },

  destroyed() {
    this.modal.destroyed();
  },

  updated() {
    this.modal.updated();
  },
};
