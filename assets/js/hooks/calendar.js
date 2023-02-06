import { Calendar } from '@fullcalendar/core';
import dayGridPlugin from '@fullcalendar/daygrid';
import timeGridPlugin from '@fullcalendar/timegrid';
import listPlugin from '@fullcalendar/list';

const isMobile = () => window.innerWidth <= 768;

const getView = () => {
  return isMobile() ? 'listWeek' : 'dayGridMonth';
};

const calendar_render = (el) => {
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
      right: 'dayGridMonth,timeGridWeek',
    },
    eventSources: [{ url: feedPath }],
    editable: true,
    selectable: true,
    windowResize: function (view) {
      const newView = getView();
      if (view !== newView) {
        calendar.changeView(getView());
      }
    },
  });

  calendar.render();
};

export default {
  mounted() {
    const { el } = this;
    calendar_render(el);
  },
  updated() {
    const { el } = this;
    calendar_render(el);
  }
};
