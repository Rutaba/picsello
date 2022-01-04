// Discovered an edge case if the user
// navigates away and the DOM is patched
// the tour needs to requery the DOM
// to set appropriate positioning
// we can avoid this by selecting from the parent

export default {
  intro_test: (el) => ({
    steps: [
      {
        title: 'Welcome',
        intro: 'Hello World! 👋',
      },
      {
        element: el.querySelector('.intro-leads-card'),
        intro: 'This step focuses on an image',
      },
      {
        title: 'Farewell!',
        element: el.querySelector('.card__image'),
        intro: 'And this is our final step!',
      },
    ]
  }),
};
