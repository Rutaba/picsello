import introJs from 'intro.js';

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

function intro_tour(component, introSteps, introId) {
  document
    .querySelector('#start-tour')
    .addEventListener('click', () =>
      startIntroJsTour(component, introSteps, introId)
    );
}

export default {
  mounted() {
    // When using phx-hook, it requires a unique ID on the element
    // instead of using a data attribute to look up the tour we need,
    // we should use the id and the data-intro-show as the trigger
    // to see if the user has seen it yet or not
    const el = this.el;
    const introId = el.id;
    const shouldSeeIntro = JSON.parse(el.dataset.introShow); // turn to an actual boolean

    if (shouldSeeIntro && !isMobile()) {
      const introSteps = intros[introId](el);

      if (!introSteps) return;
      startIntroJsTour(this, introSteps, introId);
    }
    if (intros[introId]) {
      const introSteps = intros[introId](el);
      intro_tour(this, introSteps, introId);
    }
  },
};
