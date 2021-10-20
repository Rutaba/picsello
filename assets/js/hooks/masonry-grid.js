import Masonry from "masonry-layout";

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
    const grid = document.querySelector(".masonry");
    if (grid) {
      const options = {
        itemSelector: ".item",
        columnWidth: 309,
        gutter: 20,
        fitWidth: true,
      };
      window.grid = new Masonry(grid, options);

      return window.grid;
    }
    return false;
  },
  /**
   * Masonry grid getter
   * @returns {Element|boolean|*}
   */
  get_grid() {
    if (window.grid) {
      return window.grid;
    }
    return this.init_masonry()
  },
  /**
   * Recollects all item elements to apply changes to the DOM to Masonry
   */
  reload_masonry () {
    const grid = this.get_grid();
    grid.reloadItems();
  },
  /**
   * Injects newly added photos into grid
   */
  inject_new_items() {
    const grid = this.get_grid();
    const allItems = document.querySelectorAll('.masonry .item');
    const addedItemsIds = grid.getItemElements().map(x => x.id);
    const itemsToInject = Array.from(allItems).filter(x => !addedItemsIds.includes(x.id))

    grid.addItems(itemsToInject);
    grid.layout();
  },
  /**
   * Returns true if there are more photos to load. Based on total counter
   * @returns {boolean}
   */
  hasMorePhotoToLoad() {
    let totalImagesNumber;
    const {isFavoritesShown, favoritesCount, total } = this.el.dataset;
    const amount = this.get_grid().getItemElements().length;

    if(isFavoritesShown === 'true'){
      totalImagesNumber = parseInt(favoritesCount);
    }else{
      totalImagesNumber = parseInt(total);
    }

    return amount < total;
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

    this.init_masonry();
  },
  /**
   * Reconnect callback
   */
  reconnected(){
    this.pending = this.page();
    this.inject_new_items();
  },
  /**
   * Updated callback
   */
  updated(){
    this.pending = this.page();
    this.reload_masonry();
    this.inject_new_items();
  }
};
