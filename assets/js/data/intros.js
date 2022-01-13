// Discovered an edge case if the user
// navigates away and the DOM is patched
// the tour needs to requery the DOM
// to set appropriate positioning
// we can avoid this by selecting from the parent

export default {
  intro_dashboard: (el) => ({
    steps: [
      {
        title: 'Welcome to Picsello!',
        intro: 'Let’s get started with the basics.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('h1'),
      },
      {
        element: el.querySelector('.intro-needs-attention'),
        title: 'Needs attention section',
        intro:
          'The “needs attention” section will guide you through which steps you should focus on next. The more important an action is, the more we will highlight it to make sure you don’t miss it.',
        position: 'bottom-middle-aligned',
      },
      {
        title: 'Confirm your email',
        element: el.querySelector('.intro-confirmation'),
        intro:
          'It looks like you need to confirm your email. A confirmation email will be sent to the email address associated with your account. Click on the link within the email to confirm the account. If you’re having trouble, you can find instructions on how to do this here, in our help center.',
        position: 'bottom-middle-aligned',
      },
      {
        title: 'Create your first lead',
        element: el.querySelector('.intro-first-lead'),
        intro:
          'Next up, you’ll need to create your first lead. Once you get to this step, we’ll guide you through how.',
        position: 'bottom-middle-aligned',
      },
      {
        title: 'Connect to Stripe',
        element: el.querySelector('.intro-stripe'),
        intro:
          'Once you’ve created your first lead, you’ll need to connect your Stripe account so you can send proposals, sign contracts, and get paid for your jobs.',
        position: 'bottom-middle-aligned',
      },
      {
        title: 'Packages',
        element: '',
        intro:
          'Create or edit package templates that work best for your job types.',
        position: 'bottom-middle-aligned',
      },
      {
        title: 'Your inbox',
        element: el.querySelector('.intro-inbox'),
        intro:
          'We’ve created an easy way for you to see all your communications with your clients in one place! As soon as you send a booking proposal, all communications between you and your client will be logged in your inbox. You can send emails through your Picsello inbox, or simply use it as a record of client conversations.',
        position: 'bottom-middle-aligned',
      },
      {
        title: 'Marketing',
        element: el.querySelector('.intro-marketing'),
        intro:
          'We want you to have all the tools you need to succeed! Using our marketing tools, you can create a public profile where clients can find you, and create email campaigns for your clients.',
        position: 'bottom-middle-aligned',
      },
    ].filter((obj) => obj?.element), // Hack to filter out steps that don't exist in the DOM
  }),
};
