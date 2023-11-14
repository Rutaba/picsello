export default {
  openMobileDrawer() {
    document.body.classList.add('overflow-hidden');
  },
  closeMobileDrawer() {
    document.body.classList.remove('overflow-hidden');
  },
  openDesktopDrawer(main) {
    main.classList.remove('sm:ml-64');
    main.classList.add('sm:ml-12');
  },
  closeDesktopDrawer(main) {
    main.classList.add('sm:ml-64');
    main.classList.remove('sm:ml-12');
  },
  mounted() {
    const main = document.querySelector('main');

    this.el.addEventListener('mousedown', (e) => {
      const targetIsOverlay = (e) => e.target.id === 'sidebar-wrapper';

      if (targetIsOverlay(e)) {
        const mouseup = (e) => {
          if (targetIsOverlay(e)) {
            this.pushEventTo(this.el.dataset.target, 'open');
          }
          this.el.removeEventListener('mouseup', mouseup);
        };
        this.el.addEventListener('mouseup', mouseup);
      }
    });

    this.handleEvent('sidebar:mobile', ({ is_drawer_open }) => {
      is_drawer_open
        ? this.closeMobileDrawer(main)
        : this.openMobileDrawer(main);
    });

    this.handleEvent('sidebar:collapse', ({ is_drawer_open }) => {
      is_drawer_open
        ? this.closeDesktopDrawer(main)
        : this.openDesktopDrawer(main);
    });
  },
};
