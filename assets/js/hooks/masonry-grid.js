import Muuri from 'muuri';
import isMobile from '../utils/isMobile';

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
  if (element && !element.classList.contains('selected_none')) {
    items.forEach((item) => {
      const e = item.querySelector('.toggle-it');
      e && e.classList.add('item-border');
    });
  }
  return items;
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

  grid_alignment() {
    const grid = this.get_grid();
    const grid_items = grid.getItems();
    const w = grid['_width'];
    var iw = 0;
    var count = 1;

    grid_items.some((item, index) => {
      const iw_total = iw + item['_width'];
      if (w > iw_total) {
        iw = iw_total;
      } else {
        count += index;
        return true;
      }
    });
    
    if (isMobile()) {
      this.el.style.width = '100%';
      const offset = (w - iw - count * 12) / 2;
      if (offset > 0) {
        this.el.style.marginLeft = offset + 'px';
      } else {
        this.el.style.marginLeft = '10px';
      }
    }
  },

  load_more() {
    if (this.hasMorePhotoToLoad()) {
      this.pushEvent('load-more', {});
    }
  },

  /**
   * Recollects all item elements to apply changes to the DOM to Masonry
   */
  reload_masonry() {
    const item_id = '#' + this.el.dataset.id + ' .item';
    const grid = this.get_grid();
    const grid_items = grid.getItems();
    const items = document.querySelectorAll(item_id);
    grid.remove(grid_items);
    grid.add(items);
    grid.refreshItems();
    this.grid_alignment();
  },

  /**
   * Injects newly added photos into grid
   */
  inject_new_items() {
    const grid = this.grid;
    const grid_id = '#' + this.el.dataset.id + ' .item';
    const addedItemsIds = grid.getItems().map((x) => x.getElement().id);
    const allItems = document.querySelectorAll(grid_id);
    const itemsToInject = Array.from(allItems).filter(
      (x) => !addedItemsIds.includes(x.id)
    );
    if (itemsToInject.length > 0) {
      const items = maybeSelectedOnScroll(itemsToInject);
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
    this.handleEvent('reload_grid', ({}) => this.reload_masonry());
    this.handleEvent('remove_loader', ({}) => this.remove_loader());
    this.handleEvent('remove_items', ({ ids: ids }) => this.remove_items(ids));
    this.handleEvent('select_mode', ({ mode: mode }) => this.select_mode(mode));
  },

  remove_loader() { 
    const items_class = '#' + this.el.dataset.id + ' .photo-loader';
    const elements = document.querySelectorAll(items_class)
    const grid = this.get_grid();
    let items = [];
    elements.forEach((item) => {
      items.push(grid.getItem(item));
    });
    if (items.length > 0) {
      grid.remove(items, { removeElements: true });
      this.reload_masonry();
    }
  },

  remove_item(id) {
    const grid = this.get_grid();
    const itemElement = document.getElementById(`photo-item-${id}`);
    if (itemElement) {
      const item = grid.getItem(itemElement);
      grid.remove([item], { removeElements: true });
    }
  },

  remove_items(ids) {
    const grid = this.get_grid();
    let items = [];
    ids.forEach((id) => {
      const itemElement = document.getElementById(`photo-item-${id}`);
      if (itemElement) {
        items.push(grid.getItem(itemElement));
      }
    });
    if (items.length > 0) {
      grid.remove(items, { removeElements: true });
    }
  },

  select_mode(mode) {
    const items = document.querySelectorAll('.galleryItem > .toggle-it');
    switch (mode) {
      case 'selected_none':
        items.forEach((item) => {
          item.classList.remove('item-border');
        });
        break;
      default:
        items.forEach((item) => {
          item.classList.add('item-border');
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
    window.addEventListener('scroll', (_e) => {
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
    this.load_more();
    this.grid_alignment();
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
      this.load_more();
    } else {
      this.inject_new_items();
    }

    if(grid['_layout']['items'].length > 0) {
      this.el.style.height = grid['_layout']['styles']['height'];
    }
    this.grid_alignment();
  },
};
