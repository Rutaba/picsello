import flatpickr from 'flatpickr';

export default {
  mounted() {
    const { el } = this;
    const {
      timeOnly,
      timePicker,
      minDate,
      maxDate,
      customFormat,
      customTimeFormat,
    } = el.dataset;

    this.pickr = flatpickr(this.el, {
      wrap: true,
      enableTime: timePicker ? true : false,
      minDate: minDate ? minDate : null,
      maxDate: maxDate ? maxDate : null,
      enableTime: timeOnly ? true : false,
      noCalendar: timeOnly ? true : false,
      dateFormat: customTimeFormat || 'H:i',
      altInput: customFormat ? true : false,
      altFormat: customFormat || 'd M Y',
      dateFormat: this.el.dataset.pickrDateFormat || 'Y-m-d',
    });
  },

  destroyed() {
    this.pickr.destroy();
  },

  updated() {},
};
