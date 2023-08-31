import { Calendar } from '@fullcalendar/core';
import dayGridPlugin from '@fullcalendar/daygrid';
import timeGridPlugin from '@fullcalendar/timegrid';
import listPlugin from '@fullcalendar/list';

const isMobile = () => window.innerWidth <= 768;

const getView = () => {
  return isMobile() ? 'listWeek' : 'dayGridMonth';
};

const calendar_render = (component, el) => {
  const { timeZone, feedPath } = el.dataset;

  const calendar = new Calendar(el, {
    height: 'auto',
    plugins: [dayGridPlugin, listPlugin, timeGridPlugin],
    timeZone,
    height: 'auto',
    initialView: getView(),
    headerToolbar: {
      left: 'prev,next today',
      center: 'title',
      right: 'dayGridMonth,timeGridWeek,timeGridDay',
    },
    eventBackgroundColor: 'green',
    eventBorderColor: 'green',
    eventColor: 'green',
    eventSources: [{ url: feedPath }],
    eventClick: function (info) {
      component.pushEvent('event-detail', { event: info.event })
    },
    editable: true,
    selectable: true,
    windowResize: function (view) {
      const newView = getView();
      if (view !== newView) {
        calendar.changeView(getView());
      }
    },
    loading: function (isLoading) {
      const loadingEl = document.querySelector('#calendar-loading');
      if (isLoading) {
        el.classList.add('loading');
        loadingEl.classList.remove('hidden');
      } else {
        el.classList.remove('loading');
        loadingEl.classList.add('hidden');
      }
    },
  });

  calendar.render();
};

export default {
  mounted() {
    const { el } = this;
    calendar_render(this, el);
  },
  updated() {
    const { el } = this;
    calendar_render(this, el);
  },
};
