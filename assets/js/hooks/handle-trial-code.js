const storageName = 'picsello_trialCode';
const queryString = window.location.search;

function saveCodefromURLtoLocalStorage() {
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

    console.log(saveCodefromURLtoLocalStorage());

    handle === 'retrieve'
      ? this.pushEvent('trial-code', { code: saveCodefromURLtoLocalStorage() })
      : saveCodefromURLtoLocalStorage();
  },
};
