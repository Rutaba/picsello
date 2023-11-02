export default {
  click(e) {
    if (
      (e.type && e.type == 'contextmenu') ||
      (e.button && e.button == 2) ||
      (e.which && e.which == 3)
    ) {
      if (
        e.target.tagName == 'IMG' ||
        e.target.tagName == 'CANVAS' ||
        e.target.classList.contains('galleryItem') ||
        e.target.classList.contains('js-disable-right-click')
      ) {
        if (window.opera) window.alert('');

        return false;
      }
    }
  },
  mounted() {
    document.onmousedown = this.click;
    document.oncontextmenu = this.click;
  },
};
