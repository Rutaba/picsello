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
        element: el.querySelector('.intro-next-up'),
        title: 'Next Up section',
        intro:
          'The “Next Up” section will guide you through which steps you should focus on next. The more important an action is, the more we will highlight it to make sure you don’t miss it.',
        position: 'bottom-middle-aligned',
      },
      {
        title: 'Confirm your email',
        element: el.querySelector('.intro-confirmation'),
        intro:
          'It looks like you need to confirm your email. A confirmation email will be sent to the email address associated with your account. Click on the link within the email to confirm the account. If you’re having trouble, you can find instructions on how to do this in our <a href="https://support.picsello.com" target="_blank">help center</a>.',
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
    ].filter((obj) => obj?.element),
  }),
  intro_inbox: (el) => ({
    showBullets: false,
    steps: [
      {
        title: 'Welcome to your inbox!',
        intro:
          'Once you send a booking proposal or other communication to a client, the communications will be logged in your inbox. You’ll be able to send messages, and keep track of all your messages to and from clients, all in one place.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('h1'),
      },
    ].filter((obj) => obj?.element),
  }),
  intro_marketing: (el) => ({
    steps: [
      {
        title: 'Promotional emails',
        intro:
          'Picsello makes it easy to reach out to your customers at any time. You can create custom messages and send them to either all of your contacts, or only those that are not currently leads.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('.intro-promotional'),
      },
      {
        title: 'Your Public Profile',
        intro:
          'This is your custom, Picsello-hosted site that clients will be able to use to find and contact you.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('.intro-profile'),
      },
    ].filter((obj) => obj?.element),
  }),
  intro_leads_empty: (el) => ({
    showBullets: false,
    steps: [
      {
        title: 'Your leads',
        intro:
          'Before you can create jobs, you need to create leads. You’ll add your client’s name and email address, and information about the shoot they’re interested in doing. Don’t worry, you won’t have to add this information a second time - we’ll help you convert the lead into a job once you and your client have agreed to work together.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('.intro-leads'),
      },
    ].filter((obj) => obj?.element),
  }),
  intro_leads_new: (el) => ({
    steps: [
      {
        title: 'Yay!',
        intro:
          'Your lead has been successfully created! Just a few more steps to go to turn it into a job.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('h1'),
      },
      {
        title: 'Add a package',
        intro:
          'This will include details like pricing and how many shoots are included. Packages are reusable, and if you’re unsure where to start, we have preset templates you can use as a guide.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('.intro-add-package'),
      },
      {
        title: 'Connect Stripe',
        intro:
          'Connect a Stripe account or create one to make it easy for your clients to pay you.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('.intro-stripe'),
      },
      {
        title: 'Send a proposal',
        intro:
          'Once the above steps are completed, you’ll be able to send your client a booking proposal for them to review.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('.intro-finish-proposal'),
      },
    ].filter((obj) => obj?.element),
  }),
  intro_settings_profile: (el) => ({
    showBullets: false,
    steps: [
      {
        title: 'Account',
        intro: 'Manage your Picsello account from here.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('#intro_settings_profile h1'),
      },
    ].filter((obj) => obj?.element),
  }),
  intro_settings_packages: (el) => ({
    showBullets: false,
    steps: [
      {
        title: 'Package Templates',
        intro: 'View preset packages or create your own.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('#intro_settings_packages h1'),
      },
    ].filter((obj) => obj?.element),
  }),
  intro_settings_pricing: (el) => ({
    showBullets: false,
    steps: [
      {
        title: 'Gallery Store Pricing',
        intro:
          'Bulk-edit your gallery offerings, or review your gallery pricing at-a-glance, with access to all your gallery pricing in one place.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('#intro_settings_pricing h1'),
      },
    ].filter((obj) => obj?.element),
  }),
  intro_settings_public_profile: (el) => ({
    showBullets: false,
    steps: [
      {
        title: 'Public Profile',
        intro:
          'We offer a Public Profile page that will allow potential clients to contact you directly through a website that we host.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('#intro_settings_public_profile h1'),
      },
    ].filter((obj) => obj?.element),
  }),
  intro_settings_contacts: (el) => ({
    showBullets: false,
    steps: [
      {
        title: 'Contacts',
        intro:
          'If someone isn’t a lead yet, but you want to keep track of their contact information, you can add them as a contact here. You can also convert them into a lead later.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('#intro_settings_contacts h1'),
      },
    ].filter((obj) => obj?.element),
  }),
};
