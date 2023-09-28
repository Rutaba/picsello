import { Calendar } from '@fullcalendar/core';
import dayGridPlugin from '@fullcalendar/daygrid';
import interactionPlugin from "@fullcalendar/interaction";
import listPlugin from '@fullcalendar/list';

const isMobile = () => window.innerWidth <= 768;

const getView = () => {
  return isMobile() ? 'listWeek' : 'dayGridMonth';
};

const calendar_render = (el, component) => {
  const { timeZone, feedPath } = el.dataset;

  const calendar = new Calendar(el, {
    themeSystem: 'cosmo',
    height: 600,
    plugins: [dayGridPlugin, listPlugin, interactionPlugin],
    timeZone,
    initialView: getView(),
    headerToolbar: {
      right: 'today prev next'
    },
    eventSources: [{ url: feedPath }],
    selectable: true,
    windowResize: function (view) {
      const newView = getView();
      if (view !== newView) {
        calendar.changeView(getView());
      }
    },
  });

  calendar.render();
  calendar.on('dateClick', function(info) {
    component.pushEvent("calendar-date-changed", {date: info.dateStr})
  });
};

export default {
  mounted() {
    const { el } = this;
    calendar_render(el, this);
  },
  updated() {
    const { el } = this;
    calendar_render(el, this);
  }
};
