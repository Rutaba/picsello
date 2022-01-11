import introJs from 'intro.js';

import intros from '../data/intros';

export default {
  mounted() {
    // When using phx-hook, it requires a unique ID on the element
    // instead of using a data attribute to look up the tour we need
    // we should use the id and the data-intro-show as the trigger
    // to see if the user has seen it yet or not
    const el = this.el;
    const introId = el.id;
    const shouldSeeIntro = JSON.parse(el.dataset.introShow); // turn to an actual boolean
    const introSteps = intros[introId](el);

    // In case we ever fat finger the introId on the wrapper element
    // checking that the user should 1. see it and 2. we have the steps
    shouldSeeIntro && introSteps
      ? introJs()
          .setOptions(introSteps)
          .onexit(() => {
            // if user clicks 'x' or the overlay
            this.pushEvent('intro_js', {
              action: 'dismissed',
              intro_id: introId
            });
          })
          .onbeforeexit(() => {
            // if user has completed the entire tour
            this.pushEvent('intro_js', {
              action: 'completed',
              intro_id: introId
            });
          })
          .start()
      : null;

    // We are using hints as tooltips and they will
    // using the data-attribute API to embed directly
    // into the HTML to avoid JS bloat
    // see https://introjs.com/docs/hints/attributes
    introJs().addHints();
  }
};
