import { Modal } from './shared';

export default {
  mounted() {
    const { el } = this;
    console.log(el)
    // const active = this.el.querySelector('dev.grid-item > a');
    // console.log()
    // ul.navbar-nav > li

    // active.addEventListener('click', (e) => {
    //   console.log(e)
    //   const a = e.querySelector('dev.grid-item > a');
    //   console.log(a)
    // });

    const attr = '.' + el.getAttribute('target-class');
    const content = el.querySelector(attr);
    console.log(content)
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
