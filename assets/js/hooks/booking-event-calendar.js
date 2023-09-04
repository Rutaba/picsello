import { Calendar } from '@fullcalendar/core';
import dayGridPlugin from '@fullcalendar/daygrid';
import interactionPlugin from "@fullcalendar/interaction"; 

const isMobile = () => window.innerWidth <= 768;

const getView = () => {
  return isMobile() ? 'listWeek' : 'dayGridMonth';
};

const calendar_render = (el, component) => {
  const { timeZone } = el.dataset;

  const calendar = new Calendar(el, {
    themeSystem: 'cosmo',
    height: 'auto',
    plugins: [dayGridPlugin, interactionPlugin],
    timeZone,
    initialView: getView(),
    headerToolbar: {
      right: 'today prev next',
      left: 'title',
      // right: 'dayGridMonth,timeGridWeek',
    },
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
  calendar.on('dateClick', function(info) {
    console.log(info);
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
