// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import '../css/app.scss';

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
import 'phoenix_html';
import { Socket } from 'phoenix';
import topbar from 'topbar';
import { LiveSocket } from 'phoenix_live_view';

import '@fontsource/be-vietnam/100.css';
import '@fontsource/be-vietnam/400.css';
import '@fontsource/be-vietnam/500.css';
import '@fontsource/be-vietnam/600.css';
import '@fontsource/be-vietnam/700.css';
import Phone from './hooks/phone';
import Quill from './hooks/quill';
import Select from './hooks/select';

const Modal = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      if (e.target.id === 'modal') {
        this.pushEvent('modal', { action: 'close' });
      }
    });

    this.keydownListener = (e) => {
      if (e.key === 'Escape') {
        this.pushEvent('modal', { action: 'close' });
      }
    };

    document.addEventListener('keydown', this.keydownListener);

    this.handleEvent('modal:close', () => {
      this.el.classList.add('opacity-0');
    });
  },

  destroyed() {
    document.removeEventListener('keydown', this.keydownListener);
  },
};

const LockBodyScroll = {
  mounted() {
    document.body.style.overflow = 'hidden';
  },
  destroyed() {
    document.body.style.overflow = '';
  },
};

const ClearInput = {
  mounted() {
    const { inputName } = this.el.dataset;
    const input = this.el.parentElement.querySelector(
      `input[name*=${inputName}]`
    );

    this.el.addEventListener('click', () => {
      input.value = null;
      input.dispatchEvent(new Event('input', { bubbles: true }));
    });
  },
};

const TimeZoneInput = {
  mounted() {
    const { timeZone } = Intl.DateTimeFormat().resolvedOptions();
    this.el.value = timeZone;
  },
};

const Hooks = {
  ClearInput,
  LockBodyScroll,
  Modal,
  Phone,
  Quill,
  Select,
  TimeZoneInput,
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute('content');
let liveSocket = new LiveSocket('/live', Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
});

// Show progress bar on live navigation and form submits
topbar.config({
  barColors: { 0: '#00ADC9' },
  shadowColor: 'rgba(0, 0, 0, .3)',
});
window.addEventListener('phx:page-loading-start', (_info) => topbar.show());
window.addEventListener('phx:page-loading-stop', (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window['liveSocket'] = liveSocket;
