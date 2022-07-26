import Cookies from 'js-cookie';

export default {
  mounted() {
    const { el } = this;
    const name = el.dataset.name;
    if(Cookies.get(name)) {
      this.pushEvent('view_gallery', {});
    }else {
      const footer = document.querySelector('.footer-cookie');
      footer.classList.add('md:hidden'); 
      el.classList.remove('hidden');
    }
  },

  updated() {
    const { el } = this;
    if(el.dataset.active == 'true') {
      Cookies.set(el.dataset.name, true, { expires: Number(el.dataset.max_age), path: '/' })
    } else {
      el.classList.remove('hidden');
    }
  },
};