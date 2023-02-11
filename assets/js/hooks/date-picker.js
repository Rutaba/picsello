import AirDatepicker from 'air-datepicker';
import localeEn from 'air-datepicker/locale/en';
import { createPopper } from '@popperjs/core';
import isMobile from '../utils/isMobile';

const buildDate = ([hrs, min, sec]) => {
  let date = new Date();

  date.setHours(hrs);
  date.setMinutes(min);
  date.setSeconds(sec);

  return date;
};

export default {
  mounted() {
    const { el } = this;
    const {
      timeOnly,
      timePicker,
      inline,
      minDate,
      maxDate,
      selectedDate,
      customFormat,
      customTimeFormat,
    } = el.dataset;
    const visibleInput = el.querySelector('input[type="text"]');
    const hiddenInput = el.querySelector('input[type="hidden"]');
    let finalFormat = customFormat ? customFormat : 'yyyy-MM-dd';

    const options = {
      altField: hiddenInput,
      altFieldDateFormat: timeOnly ? 'HH:m' : finalFormat,
      onlyTimepicker: timeOnly ? true : false,
      timepicker: timeOnly || timePicker ? true : false,
      timeFormat: customTimeFormat ? customTimeFormat : '',
      inline: inline ? true : false,
      minDate: minDate ? minDate : '',
      maxDate: maxDate ? maxDate : '',
      isMobile: isMobile(),
      locale: localeEn,
      onSelect: () => {
        hiddenInput.dispatchEvent(new Event('input', { bubbles: true }));
      },
      position({ $datepicker, $target, $pointer, done }) {
        let popper = createPopper($target, $datepicker, {
          placement: 'bottom',
          modifiers: [
            {
              name: 'flip',
              options: {
                padding: {
                  top: 64,
                },
              },
            },
            {
              name: 'offset',
              options: {
                offset: [0, 20],
              },
            },
            {
              name: 'arrow',
              options: {
                element: $pointer,
              },
            },
          ],
        });

        return function completeHide() {
          popper.destroy();
          done();
        };
      },
    };

    this.datePicker = new AirDatepicker(visibleInput, options);

    if (selectedDate) {
      const date = timeOnly ? buildDate(selectedDate.split(':')) : selectedDate;

      this.datePicker.selectDate(date, {
        updateTime: timeOnly ? true : false,
      });
    }
  },

  destroyed() {
    this.datePicker.destroy();
  },

  updated() {},
};
