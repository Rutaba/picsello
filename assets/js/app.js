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
import Analytics from './hooks/analytics';
import AutoHeight from './hooks/auto-height';
import Calendar from './hooks/calendar';
import Clipboard from './hooks/clipboard';
import DragDrop from './hooks/drag-drop';
import IFrameAutoHeight from './hooks/iframe-auto-height';
import PrefixHttp from './hooks/prefix-http';
import HelpScout from './hooks/help-scout';
import IntroJS from './hooks/intro';
import MasonryGrid from './hooks/masonry-grid';
import PercentMask from './hooks/percent-mask';
import Phone from './hooks/phone';
import PhotoUpdate from './hooks/photo-update';
import PlacesAutocomplete from './hooks/places-autocomplete';
import Preview from './hooks/preview';
import PriceMask from './hooks/price-mask';
import Quill, {ClearQuillInput} from './hooks/quill';
import ScrollIntoView from './hooks/scroll-into-view';
import Select from './hooks/select';
import SelectHighlighter from './hooks/select-highlighter';
import ToggleContent from './hooks/toggle-content';
import ToggleAlbumDropdown from './hooks/toggle-album-dropdown';
import ToggleNavArrow from './hooks/toggle-nav-arrow';
import ToggleSiblings from './hooks/toggle-siblings';
import GalleryMobile from './hooks/gallery-mobile';
import ResumeUpload from './hooks/resume_upload';
import GallerySelector from './hooks/gallery-selector';

const Modal = {
  mounted() {
    this.el.addEventListener('mousedown', (e) => {
      const targetIsOverlay = (e) => e.target.id === 'modal-wrapper';

      if (targetIsOverlay(e)) {
        const mouseup = (e) => {
          if (targetIsOverlay(e)) {
            this.pushEvent('modal', { action: 'close' });
          }
          this.el.removeEventListener('mouseup', mouseup);
        };
        this.el.addEventListener('mouseup', mouseup);
      }
    });

    this.keydownListener = (e) => {
      if (e.key === 'Escape') {
        this.pushEvent('modal', { action: 'close' });
      }
    };

    document.addEventListener('keydown', this.keydownListener);

    this.handleEvent('modal:open', () => {
      document.body.classList.add('overflow-hidden');
    });

    this.handleEvent('modal:close', () => {
      this.el.classList.add('opacity-0');
      document.body.classList.remove('overflow-hidden');
    });
  },

  destroyed() {
    document.removeEventListener('keydown', this.keydownListener);
    document.body.classList.remove('overflow-hidden');
  },
};

const ClearInput = {
  mounted() {
    const { el } = this;
    const {
      dataset: { inputName },
    } = el;

    const input = this.el
        .closest('form')
        .querySelector(`*[name*='${inputName}']`);

    let inputWasFocussed = false;

    input.addEventListener('blur', (e) => {
      inputWasFocussed = e.relatedTarget === el;
    });

    this.el.addEventListener('click', () => {
      input.value = null;
      input.dispatchEvent(new Event('input', { bubbles: true }));
      if (inputWasFocussed) input.focus();
    });
  },
};

const TZCookie = {
  mounted() {
    const {timeZone} = Intl.DateTimeFormat().resolvedOptions();
    document.cookie = `time_zone=${timeZone}; path=/`;
  },
};

const Hooks = {
  AutoHeight,
  Calendar,
  ClearInput,
  ClearQuillInput,
  Clipboard,
  DragDrop,
  GalleryMobile,
  IFrameAutoHeight,
  HelpScout,
  IntroJS,
  MasonryGrid,
  Modal,
  PercentMask,
  Phone,
  PhotoUpdate,
  PlacesAutocomplete,
  PrefixHttp,
  Preview,
  PriceMask,
  Quill,
  ScrollIntoView,
  Select,
  SelectHighlighter,
  TZCookie,
  ToggleContent,
  ToggleAlbumDropdown,
  ToggleNavArrow,
  ToggleSiblings,
  ResumeUpload,
  GallerySelector,
};

let Uploaders = {};
Uploaders.GCS = function (entries, onViewError) {
  (function (items) {
    let queue = []
    const try_next = () =>
      setTimeout(() => {
        const next = queue.shift();
        if (next) {
          go(next);
        }
      }, 10);

    const go = (entry) => {
      let formData = new FormData();
      let { url, fields } = entry.meta;

      Object.entries(fields).forEach(([key, val]) => formData.append(key, val));
      formData.append('file', entry.file);

      let xhr = new XMLHttpRequest();
      onViewError(() => {
        try_next();
        xhr.abort();
      });
      xhr.onload = () => {
        try_next();
        xhr.status === 204 ? entry.progress(100) : entry.error();
      };
      xhr.onerror = () => {
        try_next();
        entry.error();
      };
      xhr.upload.addEventListener('progress', (event) => {
        if (event.lengthComputable) {
          let percent = Math.round((event.loaded / event.total) * 100);
          if (percent < 100) {
            entry.progress(percent);
          }
        }
      });
      xhr.open('POST', url, true);
      xhr.send(formData);
    };

    queue = items.splice(5);

    items.forEach(go);
  })(entries);
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute('content');
let liveSocket = new LiveSocket('/live', Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
  uploaders: Uploaders,
});

// Show progress bar on live navigation and form submits
topbar.config({
  barColors: { 0: '#00ADC9' },
  shadowColor: 'rgba(0, 0, 0, .3)',
});
let topBarScheduled = undefined;
window.addEventListener('phx:page-loading-start', () => {
  if (!topBarScheduled) {
    topBarScheduled = setTimeout(() => topbar.show(), 120);
  }
});
window.addEventListener('phx:page-loading-stop', (info) => {
  clearTimeout(topBarScheduled);
  topBarScheduled = undefined;
  topbar.hide();
  Analytics.init(info);
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window['liveSocket'] = liveSocket;
