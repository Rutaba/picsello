import IMask from 'imask';

export default {
  mounted() {
    IMask(this.el, { mask: '(000) 000-0000' });
  },
};

