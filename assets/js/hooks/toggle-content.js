export default {
  mounted() {
    const { el } = this;
    const content = el.querySelector('.toggle-content');

    function clickOutside(e) {
      const isOutside = e.target.closest(`#${el.id}`) === null;

      if (isOutside) {
        close();
      }
    }

    this.removeClickOutside = () => {
      document.body.removeEventListener('click', clickOutside);
    };

    const close = () => {
      content.classList.add('hidden');
      this.removeClickOutside();
    };

    const open = () => {
      content.classList.remove('hidden');

      document.body.addEventListener('click', clickOutside);
    };

    this.isClosed = () => content.classList.contains('hidden');

    el.addEventListener('click', () => {
      if (this.isClosed()) {
        open();
      } else {
        close();
      }
    });
  },

  destroyed() {
    this.removeClickOutside();
  },

  updated() {
    if (this.isClosed()) {
      this.removeClickOutside();
    }
  },
};
