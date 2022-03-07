import { Modal } from './shared';

export default {
  mounted() {
    const { el } = this;

    const attr = '.' + el.getAttribute('target-class');
    const content = el.querySelectorAll(attr);

    el.addEventListener('click', (e) => {
      content.forEach((element, i) => {
        element.classList.add('hidden');
      });      
      e.target.nextElementSibling.classList.remove('hidden')
    });

    this.modal = Modal({el});
  },

  destroyed() {
    this.modal.destroyed();
  },

  updated() {
    this.modal.updated();
  },
};
