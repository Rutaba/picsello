import flatpickr from 'flatpickr';

export default {
  mounted() {
    const { el } = this;
    const {
      timeOnly,
      timePicker,
      minDate,
      maxDate,
      customDisplayFormat,
      customDateFormat,
    } = el.dataset;

    this.pickr = flatpickr(this.el, {
      wrap: true,
      enableTime: timePicker ? true : false,
      minDate: minDate ? minDate : null,
      maxDate: maxDate ? maxDate : null,
      noCalendar: timeOnly ? true : false,
      altInput: true,
      altFormat: customDisplayFormat || timePicker ? 'm/d/Y h:i K' : 'm/d/Y',
      dateFormat: customDateFormat || 'Y-m-d',
    });
  },

  destroyed() {
    this.pickr.destroy();
  },

  updated() {},
};
