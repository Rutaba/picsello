import introJs from 'intro.js';

import intros from '../data/intros';

function isMobile() {
  const UA =
    /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
      window.navigator.userAgent
    );

  return UA || window?.matchMedia('(max-width: 480px)')?.matches || false;
}

export default {
  mounted() {
    // When using phx-hook, it requires a unique ID on the element
    // instead of using a data attribute to look up the tour we need,
    // we should use the id and the data-intro-show as the trigger
    // to see if the user has seen it yet or not
    const el = this.el;
    const introId = el.id;
    const isHintsOnly = introId.includes('intro_hints_only'); // ran into a use case where we only need hints using phx-hook
    const shouldSeeIntro = !isHintsOnly && JSON.parse(el.dataset.introShow); // turn to an actual boolean

    // We are using hints as tooltips and they will
    // using the data-attribute API to embed directly
    // into the HTML to avoid JS bloat
    // see https://introjs.com/docs/hints/attributes
    introJs().addHints().setOptions({
      hintShowButton: false,
    });

    if (shouldSeeIntro && !isMobile()) {
      const introSteps = intros[introId](el);

      if (!introSteps) return;

      introJs()
        .setOptions(introSteps)
        .onexit(() => {
          // if user clicks 'x' or the overlay
          this.pushEvent('intro_js', {
            action: 'dismissed',
            intro_id: introId,
          });
        })
        .onbeforeexit(() => {
          // if user has completed the entire tour
          this.pushEvent('intro_js', {
            action: 'completed',
            intro_id: introId,
          });
        })
        .start();
    }

    // no api for triggering hints on hover so we make our own
    // should add debouncing down the road
    document.querySelectorAll('.introjs-hint').forEach((el) => {
      if (el) {
        const step = el.dataset.step;

        if (!step) return;

        el.addEventListener('mouseenter', () => {
          const hintDialog = document.querySelector(
            `[data-step="${step}"].introjs-hintReference`
          );

          if (hintDialog) {
            // if this element exists, means the dialog is open
            // edge case that a rehover resets the DOM
            return;
          } else {
            // We have to setup hints in order for them
            // to use the showHintDialog method
            introJs()
              .addHints()
              .setOptions({
                hintShowButton: false,
              })
              .showHintDialog(JSON.parse(el.dataset.step));
          }
        });

        el.addEventListener('mouseleave', () => {
          const hintDialog = document.querySelector(
            `[data-step="${step}"].introjs-hintReference`
          );

          console.log(hintDialog);

          // IntroJS does not export a decent API to remove
          // an active hint dialog, so we'll force it
          hintDialog?.remove();
        });
      }
    });
  },
  destroyed() {
    // Intro js doesn't have a method
    // to delete itself from the DOM ran into
    // and edge case where live view navgations
    // need to force remove to reset the introHints
    // for the next view
    const hintsEl = document.querySelector('.introjs-hints');
    hintsEl?.remove();
  },
};
