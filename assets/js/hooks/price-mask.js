import Cleave from 'cleave.js';

export default {
  mounted() { applyPrefix(this) },
  updated() { applyPrefix(this) }
};

function applyPrefix(currentObj) {
  const { currency } = currentObj.el.dataset

  if (currency == 'undefind' || currency == null || currency == "") {
    currency = "$"
  }

  new Cleave(currentObj.el, {
    numeral: true,
    prefix: currency,
    numeralDecimalScale: 2,
    numeralDecimalMark: ".",
    noImmediatePrefix: true,
    numeralThousandsGroupStyle: 'thousand'
  });
}

