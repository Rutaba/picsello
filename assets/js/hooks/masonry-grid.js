import Muuri from "muuri";

/**
 * Returns true when reached either document percent or screens to bottom threshold
 *
 * @param percent of document full height
 * @param screen amount of screens left to document full height
 * @returns {boolean}
 */
const isScrolledOver = (percent, screen) => {
  const scrollTop = document.documentElement.scrollTop || document.body.scrollTop
  const scrollHeight = document.documentElement.scrollHeight || document.body.scrollHeight
  const clientHeight = document.documentElement.clientHeight

  return (scrollTop / (scrollHeight - clientHeight) * 100 > percent)
        || (scrollTop + clientHeight > scrollHeight - screen * clientHeight)
}

/**
 *  Fills gallery changes form field
 */
const setGalleryChange = (name, value) => {
  const field = document.querySelector(`#gallery_changes > input[name=${name}]`);
  if (field) {
    field.value = value;
  }
}


export default {
  /**
   * Current page getter
   * @returns {string}
   */
  page() { return this.el.dataset.page },
  /**
   * Initialize masonry grid
   *
   * @returns {boolean|*}
   */
  init_masonry () {
    const gridElement = document.querySelector("#muuri-grid");
    if (gridElement) {
      const opts = {
        layout: {
          fillGaps: true,
        },
        dragEnabled: true,
        dragStartPredicate: (item, e) => {
          const {isFavoritesShown, isSortable} = this.el.dataset;

          return isSortable === 'true' && isFavoritesShown !== 'true';
        }
      };
      const grid = new Muuri(gridElement, opts);
      grid.on('dragReleaseEnd', (item) => {
        const order = grid.getItems().map(x => parseInt(x.getElement().id.slice(11)))
        setGalleryChange('photo_order', order);
      })

      window.grid = this.grid = grid;

      return grid;
    }
    return false;
  },

  /**
   * Masonry grid getter
   * @returns {Element|boolean|*}
   */
  get_grid() {
    if (this.grid) {
      return this.grid;
    }
    return this.init_masonry()
  },

  /**
   * Recollects all item elements to apply changes to the DOM to Masonry
   */
  reload_masonry () {
    const grid = this.get_grid();
    grid.remove(grid.getItems());
    grid.add(document.querySelectorAll('#muuri-grid .item'));
  },

  /**
   * Injects newly added photos into grid
   */
  inject_new_items() {
    const grid = this.grid;
    const addedItemsIds = grid.getItems().map(x => x.getElement().id);
    const allItems = document.querySelectorAll('#muuri-grid .item');
    const itemsToInject = Array.from(allItems).filter(x => !addedItemsIds.includes(x.id))

    grid.add(itemsToInject);
  },

  /**
   * Returns true if there are more photos to load. Based on total counter
   * @returns {boolean}
   */
  hasMorePhotoToLoad() {
    const { isFavoritesShown, favoritesCount, total } = this.el.dataset;
    const amount = this.get_grid().getItems().length;

    const totalImagesNumber = isFavoritesShown === 'true'
      ? parseInt(favoritesCount)
      : parseInt(total);

    return amount < totalImagesNumber;
  },

  /**
   * Mount callback
   */
  mounted() {
    this.pending = this.page();
    window.addEventListener("scroll", e => {
      if (
        this.pending === this.page()
        && isScrolledOver(90, 1.5)
        && this.hasMorePhotoToLoad()
      ){
        this.pending = this.page() + 1
        this.pushEvent("load-more", {})
      }
    })

    const grid = this.init_masonry();
    grid.on('dragReleaseEnd', (item) => {
      const order = grid.getItems().map(x => parseInt(x.getElement().id.slice(11)))
      setGalleryChange('photo_order', order);
    });
  },

  /**
   * Reconnect callback
   */
  reconnected(){
    this.pending = this.page();
  },

  /**
   * Updated callback
   */
  updated(){
    this.pending = this.page();
    if (this.pending === "0") {
      this.reload_masonry();
    }else {
      this.inject_new_items();
    }
  }
};

