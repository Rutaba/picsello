// Discovered an edge case if the user
// navigates away and the DOM is patched
// the tour needs to requery the DOM
// to set appropriate positioning
// we can avoid this by selecting from the parent

export default {
  intro_dashboard: (el) => ({
    steps: [
      {
        element: el.querySelector('h1'),
        title: 'Welcome to Picsello!',
        intro:
          'We are so happy to have you here! We have a quick tour of your home screen to show you.',
        position: 'bottom-middle-aligned',
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
        title: 'Getting started guide',
        intro:
          'Reminder: you can always open this guide to see how to start running your business with Picsello.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('.intro-help-scout'),
      },
      {
        title: 'Connect to Stripe',
        element: el.querySelector('.intro-stripe'),
        intro:
          'Once you’ve created your first lead, you’ll need to connect your Stripe account so you can send proposals, sign contracts, and get paid for your jobs.',
        position: 'bottom-middle-aligned',
      },
      {
        title: 'Create your first lead',
        element: el.querySelector('.intro-leads-card'),
        intro:
          'Next up, you’ll need to create your first lead. Once you get to this step, we’ll guide you through how.',
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
  intro_jobs: (el) => ({
    showBullets: true,
    steps: [
      {
        title: 'Communication',
        intro:
          'Just like leads you can communicate with your client in this section and we’ll track all of your email correspondence in the thread. Head on over to your inbox to see the full conversation.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('.intro-message'),
      },
      {
        title: 'Uploading your gallery',
        intro:
          'You can create your gallery and start uploading photos here as your sessions are completed.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('.intro-gallery'),
      },
      {
        title: 'Shoot details',
        intro:
          'Here you can see all of the info that you previously entered from the lead process. Note, if you imported a job, you will need to finish filling this information out.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('[phx-value-section_id="shoot-details"] h2'),
      },
      {
        title: 'Booking details',
        intro:
          'If you ever need to refer back to any of the accepted documents from your client, you can always revisit this section.',
        position: 'bottom-middle-aligned',
        element: el.querySelector(
          '[phx-value-section_id="booking-details"] h2'
        ),
      },
    ].filter((obj) => obj?.element),
  }),
  intro_marketing: (el) => ({
    steps: [
      {
        title: 'Next Up',
        intro:
          'Similar to your home screen, the “Next Up” section will guide you through which steps you should focus on next. It will also contain useful tips & tricks for marketing your business.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('.intro-next-up'),
      },
      {
        title: 'Brand links',
        intro:
          'Here we have included quick links to some of the most used social platforms. We also have a spot for you to input your website and where you log in to manage it.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('.intro-brand-links'),
      },
      {
        title: 'Promotional emails',
        intro:
          'Picsello makes it easy to reach out to your customers at any time. You can create custom messages and send them to either all of your clients, or only those that are not currently leads.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('.intro-promotional'),
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
  intro_settings_public_profile: (el) => ({
    showBullets: true,
    steps: [
      {
        title: 'Public Profile',
        intro:
          'We offer a Public Profile page that will allow potential clients to contact you directly through a website that we host.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('#intro_settings_public_profile h1'),
      },
      {
        title: 'Embed your lead form',
        intro:
          'If you don’t want to use your Public Profile page to accept inquiries. We have embeddable code you can add to your website to allow leads to contact you through Picsello.',
        position: 'bottom-middle-aligned',
        element: el.querySelector(
          '#intro_settings_public_profile .intro-lead-form'
        ),
      },
    ].filter((obj) => obj?.element),
  }),
  intro_settings_clients: (el) => ({
    showBullets: false,
    steps: [
      {
        title: 'Clients',
        intro:
          'If someone isn’t a lead yet, but you want to keep track of their contact information, you can add them as a client here. You can also convert them into a lead later.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('#intro_settings_clients h1'),
      },
    ].filter((obj) => obj?.element),
  }),
  intro_settings_brand: (el) => ({
    showBullets: false,
    steps: [
      {
        title: 'Setup your signature',
        intro:
          'Configure the information you’d like to include in your email signature.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('#intro_settings_brand .intro-signature'),
      },
    ].filter((obj) => obj?.element),
  }),
  intro_settings_finances: (el) => ({
    showBullets: false,
    steps: [
      {
        title: 'Tax settings',
        intro:
          'Picsello relies on your tax settings set up in Stripe to determine how to charge your clients. Until you complete all tax steps within Stripe, Picsello will not charge any tax when your clients pay you. You will need to work with your certified CPA to understand how you will report products and services in your state.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('#intro_settings_finances .intro-taxes'),
      },
      {
        title: 'Viewing Stripe',
        intro:
          'Since we leverage Stripe as our payment partner, you can go there for the most complete view of your financial state within Picsello.',
        position: 'bottom-middle-aligned',
        element: el.querySelector('#intro_settings_finances .intro-stripe'),
      },
    ].filter((obj) => obj?.element),
  }),
};
