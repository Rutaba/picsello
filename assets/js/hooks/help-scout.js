const loadHelpScout = () => {
  // If no Beacon, please load script
  if (!window?.Beacon) {
    !(function (e, t, n) {
      function a() {
        var e = t.getElementsByTagName('script')[0],
          n = t.createElement('script');
        (n.type = 'text/javascript'),
          (n.async = !0),
          (n.src = 'https://beacon-v2.helpscout.net'),
          e.parentNode.insertBefore(n, e);
      }
      if (
        ((e.Beacon = n =
          function (t, n, a) {
            e.Beacon.readyQueue.push({ method: t, options: n, data: a });
          }),
        (n.readyQueue = []),
        'complete' === t.readyState)
      )
        return a();
      e.attachEvent
        ? e.attachEvent('onload', a)
        : e.addEventListener('load', a, !1);
    })(window, document, window.Beacon || function () {});
  }
};

const toggleMenu = (state = 'none') => {
  document.querySelector('#float-menu-help').style.display = state;
};

const handleMenuClose = () => {
  window.Beacon('on', 'close', () => {
    toggleMenu('block');
    window.Beacon('destroy');
  });
};

const initHelpScout = (helpScoutId, currentUserEmail, currentUserName) => {
  const beaconIsOpen =
    window?.Beacon && window?.Beacon('info')?.status?.isOpened;

  if (!beaconIsOpen) {
    window.Beacon('init', helpScoutId);
    window.Beacon('identify', {
      name: currentUserName,
      email: currentUserEmail,
    });
  }

  window.Beacon('open');
};

export default {
  mounted() {
    const el = this.el;
    const helpScoutId = el.dataset.id;
    const currentUserEmail = el.dataset.email;
    const currentUserName = el.dataset.name;
    const beaconIsOpen =
      window?.Beacon && window?.Beacon('info')?.status?.isOpened;

    // need to check if open on mount
    // to close our facade menu
    if (beaconIsOpen) {
      toggleMenu();
      handleMenuClose();
    }

    el.addEventListener('click', (e) => {
      e.preventDefault();
      toggleMenu();
      loadHelpScout();
      initHelpScout(helpScoutId, currentUserEmail, currentUserName);
      handleMenuClose();
    });
  },
};
