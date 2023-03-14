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
      altFormat: timePicker
        ? customDisplayFormat || 'm/d/Y h:i K'
        : customDisplayFormat || 'm/d/Y',
      dateFormat: customDateFormat || 'Y-m-d',
    });
  },

  destroyed() {
    this.pickr.destroy();
  },

  updated() {
    const { el } = this;
    const {
      timeOnly,
      timePicker,
      minDate,
      maxDate,
      customDisplayFormat,
      customDateFormat,
    } = el.dataset;

    const wasFormat = this.pickr.config.altFormat;

    if (customDisplayFormat !== wasFormat) {
      this.pickr.destroy();
      this.pickr = flatpickr(this.el, {
        wrap: true,
        enableTime: timePicker ? true : false,
        minDate: minDate ? minDate : null,
        maxDate: maxDate ? maxDate : null,
        noCalendar: timeOnly ? true : false,
        altInput: true,
        altFormat: timePicker
          ? customDisplayFormat || 'm/d/Y h:i K'
          : customDisplayFormat || 'm/d/Y',
        dateFormat: customDateFormat || 'Y-m-d',
      });
    }
  },
};
