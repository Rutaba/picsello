export const loadHelpScout = () => {
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

export const toggleMenu = (state = 'none') => {
  const menu = document.querySelector('#float-menu-help');
  if (menu) {
    menu.style.display = state;
  }
};

export const initHelpScout = (
  helpScoutId,
  currentUserEmail,
  currentUserName,
  article,
  ask,
  subject,
  text
) => {
  const beaconIsOpen =
    window?.Beacon && window?.Beacon('info')?.status?.isOpened;

  // check if Beacon is open to avoid
  // init twice console.error
  if (!beaconIsOpen) {
    window.Beacon('init', helpScoutId);
    // this isn't the most secure, but this would be
    // passed over the network through JS anyways
    window.Beacon('identify', {
      name: currentUserName,
      email: currentUserEmail,
    });

    if (ask !== undefined) {
      window?.Beacon('navigate', '/ask/message/');
    } else if (article) {
      window?.Beacon('config', { mode: 'neutral' });
      window?.Beacon('article', article);
      window?.Beacon('navigate', '/ask/message/');
      window?.Beacon('prefill', {
        subject,
        text,
      });
    }

    // attach listener to instance
    // to reset facade when user closes
    window.Beacon('on', 'close', () => {
      if (window.innerWidth >= 640) toggleMenu('block');
      window.Beacon('destroy');
    });
  }

  // always open after init OR toggling
  window.Beacon('open');
};

export default {
  mounted() {
    const el = this.el;
    const helpScoutId = el.dataset.id;
    const currentUserEmail = el.dataset.email;
    const currentUserName = el.dataset.name;
    const ask = el.dataset.ask;
    const article = el.dataset.article;
    const subject = el.dataset.subject;
    const text = el.dataset.text;
    const beaconIsOpen =
      window?.Beacon && window?.Beacon('info')?.status?.isOpened;

    // need to check if open on mount
    // to hide our facade menu
    if (beaconIsOpen) {
      toggleMenu();
    }

    el.addEventListener('click', (e) => {
      e.preventDefault();
      toggleMenu();
      loadHelpScout();
      initHelpScout(
        helpScoutId,
        currentUserEmail,
        currentUserName,
        article,
        ask,
        subject,
        text
      );
    });
  },
};
