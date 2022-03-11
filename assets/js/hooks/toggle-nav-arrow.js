import { Modal } from './shared';

export default {
  mounted() {
    const { el } = this;

    el.addEventListener('click', (e) => {
      handle_previous_element_arrow(el)
      handle_next_element_arrow(e)
    });

    function onClose() {}
    function isClosed() {}

    this.modal = Modal({el, onClose, isClosed});
  },

  destroyed() {
    this.modal.destroyed();
  },

  updated() {
    this.modal.updated();
  },
};


function handle_previous_element_arrow(e) {
  const previous_element = e.querySelector('.text-blue-planning-300')
  previous_element.classList.add('text-gray-700')
  previous_element.classList.remove('text-blue-planning-300')

  const arrow_element = e.querySelector('.show')
  arrow_element.classList.remove('show')
  arrow_element.classList.add('hidden')
};

function handle_next_element_arrow(e) {
  const grid_item = e.target.closest('div.grid-item')
  grid_item.querySelector('.arrow').classList.remove('hidden')
  grid_item.querySelector('.arrow').classList.add('show')
  grid_item.classList.add('text-blue-planning-300')
  grid_item.classList.remove('text-gray-700')
};
