import { Modal } from './shared';

export default {
  mounted() {
    const { el } = this;
    if (el.id == el.dataset.selected_photo_id) {
      const e = el.querySelector('.toggle-it')
      e.classList.add('item-border');
    }
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

    this.handleEvent('select_mode', ({ mode: mode }) => this.select_mode(mode));
    this.modal = Modal({ el, onOpen, onClose, isClosed });
  },

  destroyed() {
    this.modal.destroyed();
  },

  updated() {
    this.modal.updated();
  },
  select_mode(mode) {
    const items = document.querySelectorAll('.toggle-parent > .toggle-it');
    switch (mode) {
      case 'selected_none':
        items.forEach((item) => {
          item.classList.remove('item-border');
        });
        break;
      default:
        items.forEach((item) => {
          item.classList.add('item-border');
        });
        break;
    }
  }
};
