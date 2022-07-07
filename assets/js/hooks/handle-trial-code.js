const storageName = 'picsello_trialCode';

function saveCodefromURLtoLocalStorage() {
  const queryString = window.location.search;

  if (queryString === '' || !queryString.includes('code=')) {
    return localStorage.getItem(storageName);
  }

  const parseQueryString = queryString.replace(/^\?/, '').split('&');
  const retrieveCode = parseQueryString.filter((urlParts) =>
    urlParts.includes('code=')
  );
  const extractCode = retrieveCode[0].split('=')[1];

  localStorage.setItem(storageName, extractCode);

  return localStorage.getItem(storageName);
}

export default {
  mounted() {
    const { el } = this;
    const handle = el.dataset.handle;
    const code = saveCodefromURLtoLocalStorage();

    if (handle === 'retrieve') this.pushEvent('trial-code', { code });
  },
};
