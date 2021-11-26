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
 *  Prepares positionChange for backend
 */
const positionChange = (movedId, order) => {
    const orderLen = order.length;

    if (orderLen < 2) {
        return false;
    }

    if (order[0] == movedId) {
        return {
            "photo_id": movedId,
            "type": "before",
            "args": [order[1]]
        }
    }
    if (order[orderLen-1] == movedId) {
        return {
            "photo_id": movedId,
            "type": "after",
            "args": [order[orderLen-2]]
        }
    }

    if (orderLen < 3) {
        return false;
    }

    for (let i = 1; i + 1 < orderLen; i += 1){
        if (order[i] == movedId) {
            return {
                "photo_id": movedId,
                "type": "between",
                "args": [order[i-1], order[i+1]]
            }
        }
    }

    return false;
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
      grid.on('dragInit', (item) => {
        this.itemPosition = item.getPosition()
      });
      grid.on('dragReleaseEnd', (item) => {
        const order = grid.getItems().map(x => parseInt(x.getElement().id.slice(11)))
        const movedId = item.getElement().id.slice(11)
        const change = positionChange(movedId, order)

        if (change && !this.isPositionEqual(this.itemPosition, item.getPosition())) {
            this.pushEvent("update_photo_position", change)
        }
        this.itemPosition = false;
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

  init_remove_listener() {
    this.handleEvent("remove_item", ({id: id}) => this.remove_item(id))
  },
  
  remove_item(id) {
    const grid = this.get_grid();
    const itemElement = document.getElementById(`photo-item-${id}`);
    const item = grid.getItem(itemElement);

    grid.remove([item], { removeElements: true })
  },

  /**
   * Compares position objects
   */
  isPositionEqual(previousPosition, nextPosition) {
    return previousPosition.left === nextPosition.left 
        && previousPosition.top === nextPosition.top;
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
    this.init_remove_listener()
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

