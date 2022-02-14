import isMobile from '../utils/isMobile';

export default {
  mounted() {
    const el = this.el;
    if (isMobile()) {
      const show = el?.querySelector('.galleryShowMobile');
      const hide = el?.querySelector('.galleryHideDesktop');

      show?.classList.remove('hidden');
      hide?.classList.add('hidden');
    }
  },
};
