import { Calendar } from '@fullcalendar/core';
import dayGridPlugin from '@fullcalendar/daygrid';
import timeGridPlugin from '@fullcalendar/timegrid';
import listPlugin from '@fullcalendar/list';

const isMobile = () => window.innerWidth <= 768;

const getView = () => {
  return isMobile() ? 'listWeek' : 'dayGridMonth';
};

export default {
  mounted() {
    const { el } = this;
    const { timeZone, feedPath } = el.dataset;

    const calendar = new Calendar(el, {
      plugins: [dayGridPlugin, listPlugin, timeGridPlugin],
      timeZone,
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
  },
};
