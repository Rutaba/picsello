export default {
  init(info) {
    // Maps liveview redirects/patches to GA pageviews out-of-the-box
    // Requirement is to have GA/GTM loaded on the page
    if (['redirect', 'patch'].includes(info.detail.kind)) {
      window?.dataLayer.push({ event: 'pageview' });
    }
  },
};
