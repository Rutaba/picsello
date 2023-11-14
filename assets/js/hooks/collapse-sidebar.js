export default {
  openMobileDrawer() {
    this.el.setAttribute('data-drawer-open', true);
    document.body.classList.add('overflow-hidden');
  },
  closeMobileDrawer() {
    this.el.setAttribute('data-drawer-open', false);
    document.body.classList.remove('overflow-hidden');
  },
  openDesktopDrawer(main, targetEl) {
    this.el.setAttribute('data-drawer-open', true);
    targetEl.classList.add('sm:w-12');
    main.classList.remove('sm:ml-64');
    main.classList.add('sm:ml-12');
  },
  closeDesktopDrawer(main, targetEl) {
    this.el.setAttribute('data-drawer-open', false);
    targetEl.classList.remove('sm:w-12');
    main.classList.add('sm:ml-64');
    main.classList.remove('sm:ml-12');
  },
  mounted() {
    const { el } = this;
    const isOpen = el.dataset.drawerOpen === 'true';

    const mobileButton = el.querySelector('[data-drawer-type="mobile"]');
    const desktopButton = el.querySelector('[data-drawer-type="desktop"]');

    this.el.addEventListener('mousedown', (e) => {
      const targetIsOverlay = (e) => e.target.id === 'sidebar-wrapper';

      if (targetIsOverlay(e)) {
        const mouseup = (e) => {
          if (targetIsOverlay(e)) {
            this.closeMobileDrawer();
          }
          this.el.removeEventListener('mouseup', mouseup);
        };
        this.el.addEventListener('mouseup', mouseup);
      }
    });

    mobileButton.addEventListener('click', () => {
      isOpen ? this.closeMobileDrawer() : this.openMobileDrawer();
    });

    desktopButton.addEventListener('click', (e) => {
      const target = e.target.dataset.drawerTarget;
      const targetEl = el.querySelector(`#${target}`);
      const main = document.querySelector('main');

      if (targetEl.classList.contains('sm:w-12')) {
        this.closeDesktopDrawer(main, targetEl);
      } else {
        this.openDesktopDrawer(main, targetEl);
      }
    });
  },
};
