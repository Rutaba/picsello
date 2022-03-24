export default {
  updated() {
    const { ids: idsInput, selected } = this.el.dataset;
    const ids = idsInput.replace(/\s+|\[|\]/g, '').split(',');

    ids.forEach((id) => {
      document
        .getElementById('photo-' + id + '-selected')
        .classList.remove('photo-border');
    });

    document
      .getElementById('photo-' + selected + '-selected')
      .classList.add('photo-border');
  },
};
