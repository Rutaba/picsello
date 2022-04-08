import Muuri from 'muuri';

/**
 * Returns true when reached either document percent or screens to bottom threshold
 *
 * @param percent of document full height
 * @param screen amount of screens left to document full height
 * @returns {boolean}
 */
const isScrolledOver = (percent, screen) => {
  const scrollTop =
    document.documentElement.scrollTop || document.body.scrollTop;
  const scrollHeight =
    document.documentElement.scrollHeight || document.body.scrollHeight;
  const clientHeight = document.documentElement.clientHeight;

  return (
    (scrollTop / (scrollHeight - clientHeight)) * 100 > percent ||
    scrollTop + clientHeight > scrollHeight - screen * clientHeight
  );
};

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
      photo_id: movedId,
      type: 'before',
      args: [order[1]],
    };
  }
  if (order[orderLen - 1] == movedId) {
    return {
      photo_id: movedId,
      type: 'after',
      args: [order[orderLen - 2]],
    };
  }

  if (orderLen < 3) {
    return false;
  }

  for (let i = 1; i + 1 < orderLen; i += 1) {
    if (order[i] == movedId) {
      return {
        photo_id: movedId,
        type: 'between',
        args: [order[i - 1], order[i + 1]],
      };
    }
  }

  return false;
};

/**
 * Injects bydefault selected photos if selected all enabled
 */
 const maybeSelectedOnScroll = (items) => {
  const element = document.querySelector('#selected-mode');
  if (!element.classList.contains('selected_none')) {
    items.forEach(item => {
      const e = item.querySelector('.toggle-it');
      e.classList.add('photo-border');
    });
  }
  return items
};

export default {
  /**
   * Current page getter
   * @returns {string}
   */
  page() {
    return this.el.dataset.page;
  },
  /**
   * Initialize masonry grid
   *
   * @returns {boolean|*}
   */
  init_masonry() {
    const grid_id = '#' + this.el.dataset.id;
    const gridElement = document.querySelector(grid_id);
    if (gridElement) {
      const opts = {
        layout: {
          fillGaps: true,
          syncWithLayout: false,
          layoutOnResize: true,
          layoutDuration: 0,
          layoutEasing: 'ease-in',
          rounding: false,
        },
        dragEnabled: true,
        dragStartPredicate: (item, e) => {
          const { isFavoritesShown, isSortable } = this.el.dataset;

          return isSortable === 'true' && isFavoritesShown !== 'true';
        },
      };
      const grid = new Muuri(gridElement, opts);
      grid.on('dragInit', (item) => {
        this.itemPosition = item.getPosition();
      });
      grid.on('dragReleaseEnd', (item) => {
        const order = grid
          .getItems()
          .map((x) => parseInt(x.getElement().id.slice(11)));
        const movedId = item.getElement().id.slice(11);
        const change = positionChange(movedId, order);

        if (
          change &&
          !this.isPositionEqual(this.itemPosition, item.getPosition())
        ) {
          this.pushEvent('update_photo_position', change);
        }
        this.itemPosition = false;
      });

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
    return this.init_masonry();
  },

  /**
   * Recollects all item elements to apply changes to the DOM to Masonry
   */
  reload_masonry() {
    const grid = this.get_grid();
    const grid_id = '#' + this.el.dataset.id + " .item";
    grid.remove(grid.getItems());
    grid.add(document.querySelectorAll(grid_id));
    grid.refreshItems();
  },

  /**
   * Injects newly added photos into grid
   */
  inject_new_items() {
    const grid = this.grid;
    const grid_id = '#' + this.el.dataset.id + " .item";
    const addedItemsIds = grid.getItems().map((x) => x.getElement().id);
    const allItems = document.querySelectorAll(grid_id);
    const itemsToInject = Array.from(allItems).filter(
      (x) => !addedItemsIds.includes(x.id)
    );
    if(itemsToInject.length > 0) {
      const items = maybeSelectedOnScroll(itemsToInject)
      grid.add(items);
      grid.refreshItems();
    }
  },

  /**
   * Returns true if there are more photos to load.
   * @returns {boolean}
   */
  hasMorePhotoToLoad() {
    return this.el.dataset.hasMorePhotos === 'true';
  },

  init_listeners() {
    this.handleEvent('remove_item', ({ id: id }) => this.remove_item(id));
    this.handleEvent('remove_items', ({ ids: ids }) => this.remove_items(ids));
    this.handleEvent('select_mode', ({ mode: mode }) => this.select_mode(mode));
  },

  remove_item(id) {
    const grid = this.get_grid();
    const itemElement = document.getElementById(`photo-item-${id}`);
    const item = grid.getItem(itemElement);

    grid.remove([item], { removeElements: true });
  },

  remove_items(ids) {
    const grid = this.get_grid();
    let items = [];
    ids.forEach(id => {
      const itemElement = document.getElementById(`photo-item-${id}`);
      items.push(grid.getItem(itemElement))
    });
    grid.remove(items, { removeElements: true });
  },

  select_mode(mode) {
    const items = document.querySelectorAll('.galleryItem > .toggle-it');
    switch(mode){
      case 'selected_none':
        items.forEach(item => {
          item.classList.remove('photo-border');
        });
        break;
      default:
        items.forEach(item => {
          item.classList.add('photo-border');
        });
        break;
      }
  },

  /**
   * Compares position objects
   */
  isPositionEqual(previousPosition, nextPosition) {
    return (
      previousPosition.left === nextPosition.left &&
      previousPosition.top === nextPosition.top
    );
  },

  /**
   * Mount callback
   */
  mounted() {
    this.pending = this.page();
    window.addEventListener('scroll', (e) => {
      if (
        this.pending === this.page() &&
        isScrolledOver(90, 1.5) &&
        this.hasMorePhotoToLoad()
      ) {
        this.pending = this.page() + 1;
        this.pushEvent('load-more', {});
      }
    });

    this.init_masonry();
    this.init_listeners();
  },

  /**
   * Reconnect callback
   */
  reconnected() {
    this.pending = this.page();
  },

  /**
   * Updated callback
   */
  updated() {
    this.pending = this.page();
    if (this.pending === '0') {
      this.reload_masonry();
    } else {
      this.inject_new_items();
    }
  },
};
