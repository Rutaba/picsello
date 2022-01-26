export default {
  updated() {
    const photo_update = this.el.dataset.photoUpdates
    if (photo_update) {
      const obj = JSON.parse(photo_update)
      this.updatePhotoImage(obj.id, obj.url)
    }
  },

  /**
   * Update image of a photo
   */
  updatePhotoImage(id, url) {
    const img = document.querySelector(`#photo-${id} img`)
    if (img && img.src && img.src != url) {
      img.src = url
    }
  },
}
