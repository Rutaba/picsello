import introJs from 'intro.js';

import { loadHelpScout, initHelpScout, toggleMenu } from './help-scout';

import intros from '../data/intros';
import isMobile from '../utils/isMobile';

function startIntroJsTour(component, introSteps, introId) {
  introJs()
    .setOptions(introSteps)
    .onexit(() => {
      // if user clicks 'x' or the overlay
      component.pushEvent('intro_js', {
        action: 'dismissed',
        intro_id: introId,
      });
    })
    .onbeforeexit(() => {
      // if user has completed the entire tour
      component.pushEvent('intro_js', {
        action: 'completed',
        intro_id: introId,
      });
    })
    .start();

  // Hide introJs if element is clicked underneath it
  document
    .querySelector('.introjs-showElement')
    ?.addEventListener('click', () => {
      introJs().exit();
      component.pushEvent('intro_js', {
        action: 'dismissed',
        intro_id: introId,
      });
    });
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
    introJs()
      .setOptions({
        hintShowButton: false,
      })
      .addHints();

    if (shouldSeeIntro && !isMobile()) {
      const introSteps = intros[introId](el);

      if (introId === 'intro_dashboard' && el?.dataset?.id) {
        loadHelpScout();
        initHelpScout(
          el.dataset.id,
          el.dataset.email,
          el.dataset.name,
          '',
          '',
          ''
        );

        if (window?.Beacon) {
          toggleMenu();
          window?.Beacon('article', el.dataset.article);

          window?.Beacon('on', 'close', () =>
            startIntroJsTour(this, introSteps, introId)
          );
        } else {
          startIntroJsTour(this, introSteps, introId);
        }

        return;
      }

      if (!introSteps) return;

      startIntroJsTour(this, introSteps, introId);
    }
  },
  updated() {
    // remove existing intro elements of previous page
    document.querySelectorAll('.introjs-hint').forEach((el) => el.remove());

    // add new intro elements to current page
    introJs().addHints();
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
