import * as Sentry from '@sentry/browser';
import { BrowserTracing } from '@sentry/tracing';

const env = (process && process.env && process.env.NODE_ENV) || 'production';

Sentry.init({
  dsn: 'https://5296991183f042038e40dbe1b1ddb9ef@o1295249.ingest.sentry.io/4504786824921088',
  integrations: [new BrowserTracing()],
  environment: env,
  // Set tracesSampleRate to 1.0 to capture 100%
  // of transactions for performance monitoring.
  // We recommend adjusting this value in production
  tracesSampleRate: 0.3,
});

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
import ClientGalleryCookie from './hooks/client-gallery-cookie';
import Clipboard from './hooks/clipboard';
import DefaultCostTooltip from './hooks/default-cost-tooltip';
import DragDrop from './hooks/drag-drop';
import Flash from './hooks/flash';
import GalleryMobile from './hooks/gallery-mobile';
import GallerySelector from './hooks/gallery-selector';
import HandleTrialCode from './hooks/handle-trial-code';
import HelpScout from './hooks/help-scout';
import IFrameAutoHeight from './hooks/iframe-auto-height';
import ImageUploadInput from './hooks/image-upload-input';
import InfiniteScroll from './hooks/infinite-scroll';
import IntroJS from './hooks/intro';
import MasonryGrid from './hooks/masonry-grid';
import PackageDescription from './hooks/package-description';
import PageScroll from './hooks/page-scroll';
import PercentMask from './hooks/percent-mask';
import Phone from './hooks/phone';
import PhotoUpdate from './hooks/photo-update';
import PlacesAutocomplete from './hooks/places-autocomplete';
import PrefixHttp from './hooks/prefix-http';
import Preview from './hooks/preview';
import PriceMask from './hooks/price-mask';
import Quill, { ClearQuillInput } from './hooks/quill';
import ResumeUpload from './hooks/resume_upload';
import ScrollIntoView from './hooks/scroll-into-view';
import Select from './hooks/select';
import ToggleContent from './hooks/toggle-content';
import ToggleSiblings from './hooks/toggle-siblings';
import Cookies from 'js-cookie';
import FolderUpload from './hooks/folder-upload';

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
    const { timeZone } = Intl.DateTimeFormat().resolvedOptions();
    document.cookie = `time_zone=${timeZone}; path=/`;
  },
};

const CardStatus = {
  mounted() {
    this.el.addEventListener('click', () => {
      this.pushEvent('card_status', {
        status: this.el.dataset.status,
        org_card_id: this.el.id,
      });
    });
  },
};

const FinalCostInput = {
  mounted() {
    let dataset = this.el.dataset;
    let inputElm = document.getElementById(dataset.inputId);

    inputElm.addEventListener('input', () => {
      if (inputElm.value.replace('$', '') < parseFloat(dataset.baseCost)) {
        let span = document.getElementById(dataset.spanId);
        span.style.color = 'red';

        setTimeout(function () {
          span.style.color = 'white';
          inputElm.value = `$${parseFloat(dataset.finalCost).toFixed(2)}`;
        }, 3000);
      }
    });
  },
};

const SetGalleryCookie = {
  mounted() {
    let galleryType = this.el.dataset.galleryType;
    document.cookie = `GalleryType=${galleryType}; path=/`;
  },
};

const GetGalleryCookie = {
  mounted() {
    const galleryType = getCookie('GalleryType');
    document.cookie =
      'GalleryType=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
    if (galleryType != '') {
      this.pushEvent('gallery-created', { galleryType: galleryType });
    }
  },
};

function getCookie(cname) {
  let name = cname + '=';
  let decodedCookie = decodeURIComponent(document.cookie);
  let ca = decodedCookie.split(';');
  for (let i = 0; i < ca.length; i++) {
    let c = ca[i];
    while (c.charAt(0) == ' ') {
      c = c.substring(1);
    }
    if (c.indexOf(name) == 0) {
      return c.substring(name.length, c.length);
    }
  }
  return '';
}

const showWelcomeModal = {
  mounted() {
    const show = Cookies.get('show_welcome_modal');

    if (show == 'true') {
      const dateTime = new Date('1970-12-17T00:00:00');
      Cookies.set('show_welcome_modal', false, {
        expires: dateTime,
        path: '/',
      });

      this.pushEvent('open-welcome-modal', {});
    }
  },
};

const Hooks = {
  AutoHeight,
  Calendar,
  ClearInput,
  ClearQuillInput,
  ClientGalleryCookie,
  Clipboard,
  DefaultCostTooltip,
  DragDrop,
  Flash,
  GalleryMobile,
  GallerySelector,
  HandleTrialCode,
  HelpScout,
  IFrameAutoHeight,
  ImageUploadInput,
  InfiniteScroll,
  IntroJS,
  MasonryGrid,
  Modal,
  PackageDescription,
  PageScroll,
  PercentMask,
  Phone,
  PhotoUpdate,
  PlacesAutocomplete,
  PrefixHttp,
  Preview,
  PriceMask,
  Quill,
  ResumeUpload,
  ScrollIntoView,
  Select,
  TZCookie,
  ToggleContent,
  ToggleSiblings,
  ResumeUpload,
  GallerySelector,
  ClientGalleryCookie,
  CardStatus,
  FinalCostInput,
  SetGalleryCookie,
  GetGalleryCookie,
  showWelcomeModal,
  FolderUpload,
};

let Uploaders = {};
Uploaders.GCS = function (entries, onViewError) {
  (function (items) {
    let queue = [];
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
  params: { _csrf_token: csrfToken, isMobile: window.innerWidth <= 768 },
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

window.addEventListener('phx:scroll:lock', () => {
  document.body.classList.add('overflow-hidden');
});

window.addEventListener('phx:scroll:unlock', () => {
  document.body.classList.remove('overflow-hidden');
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window['liveSocket'] = liveSocket;
