export default {
  updated() {
    const photo_update = this.el.dataset.photoUpdates;
    if (photo_update) {
      const obj = JSON.parse(photo_update);
      this.updatePhotoImage(obj.id, obj.url);
    }
  },

  /**
   * Update image of a photo
   */
  updatePhotoImage(id, url) {
    const imgWrapper = document.querySelector(`#item-${id}`);
    if(imgWrapper) {
      const isLoader = imgWrapper?.querySelector('.galleryLoader');
      const img = imgWrapper.querySelector(`img`);
      if (isLoader) {
        isLoader.classList.remove('galleryLoader');
        isLoader.classList.add('galleryLoaderFinished');
        if (img && img.src && img.src != url) {
          img.src = url;
        }
      }
    }
  },
};
