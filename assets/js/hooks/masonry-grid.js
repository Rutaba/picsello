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
      e && e.classList.add('item-border');
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
        layout: function (grid, layoutId, items, width, height, callback) {
          var layout = {
            fillGaps: true,
            syncWithLayout: false,
            layoutOnResize: true,
            layoutDuration: 0,
            layoutEasing: 'ease-in',
            rounding: false,  
            id: layoutId,
            items: items,
            slots: [],
            styles: {},
          };

          var item;
          var m;
          var x = 0;
          var y = 0;
          var w = 0;
          var h = 0;

          var maxW = width / 2;
          var currentW = 0;
          var currentRowH = 0;
          var currentRowW = 0;
          var rowSizes = [];
          var rowFixes = [];

          var xPre, yPre, wPre, hPre;
          var numToFix = 0;

          for (var i = 0; i < items.length; i++) {
              item = items[i];

              m = item.getMargin();
              wPre = item.getWidth() + m.left + m.right;
              hPre = item.getHeight() + m.top + m.bottom;
              xPre += wPre;

              if (hPre > currentRowH) {
                  currentRowH = hPre;
              }

              if (w < currentRowW) {
                  currentRowW = wPre;
              }

              rowSizes.push(width / 2);
              numToFix++;
              currentW += wPre;

              var k = 0;

              for (var j = 0; j < numToFix; j++) {
                  rowSizes[i - j] -= wPre / 2;
              }

              if (numToFix > 1) {
                  rowSizes[i] -= (wPre / 2) * (numToFix - 1);
                  k += (wPre / 2);
              }

              currentW -= k;
              rowFixes.push(k);

              if (currentW >= maxW) {
                  yPre += currentRowH;
                  currentRowH = 0;
                  xPre = 0;
                  numToFix -= 1;
                  currentW = 0;
                  numToFix = 0;
                  k = 0;
              }
          }

          maxW = width / 2;
          currentW = 0;
          currentRowH = 0;
          currentRowW = 0;

          for (var i = 0; i < items.length; i++) {
              item = items[i];
              x += w;

              if (h > currentRowH) {
                  currentRowH = h;
              }

              if (w < currentRowW) {
                  currentRowW = w;
              }

              currentW += w - rowFixes[i];

              if (currentW >= maxW) {
                  y += currentRowH;
                  currentRowH = 0;
                  x = 0;
                  currentW = 0;
              }

              m = item.getMargin();
              w = item.getWidth() + m.left + m.right;
              h = item.getHeight() + m.top + m.bottom;
              layout.slots.push(x + rowSizes[i], y);
          }

          layout.styles.width = '100%';
          layout.styles.height = y + h + 1 + 'px';

          callback(layout);
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

  refresh(id, item_id) {
    const grid = this.get_grid();
    const grid_items = grid.getItems();
    const items = document.querySelectorAll(item_id);
    if(id == 'photos') {
      if(grid_items.length != items.length) {
        grid.remove(grid_items);
        grid.add(items);  
      }
    } else {
      grid.remove(grid_items);    
      grid.add(items);    
    }
  },

  load_more() {
    if((this.el.style.height.slice(0, -2) < screen.height) && this.hasMorePhotoToLoad()){
      this.pushEvent('load-more', {});
    }
  },

  /**
   * Recollects all item elements to apply changes to the DOM to Masonry
   */
  reload_masonry() {
    const id = this.el.dataset.id;
    const item_id = '#' + id + " .item";
    const uploading = this.el.dataset.uploading;
    const grid = this.get_grid();
    if(uploading == 100 || uploading == 0) {
      this.refresh(id, item_id)
    }
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
    if(itemElement) {
      const item = grid.getItem(itemElement);
      grid.remove([item], { removeElements: true });
    }
  },

  remove_items(ids) {
    const grid = this.get_grid();
    let items = [];
    ids.forEach(id => {
      const itemElement = document.getElementById(`photo-item-${id}`);
      if(itemElement) {
        items.push(grid.getItem(itemElement))
      }
    });
    if(items.length > 0) {
      grid.remove(items, { removeElements: true });
    }
  },

  select_mode(mode) {
    const items = document.querySelectorAll('.galleryItem > .toggle-it');
    switch(mode){
      case 'selected_none':
        items.forEach(item => {
          item.classList.remove('item-border');
        });
        break;
      default:
        items.forEach(item => {
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
    this.load_more();
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
    const grid = this.get_grid();
    this.pending = this.page();

    if (this.pending === '0') {
      this.load_more();
      this.reload_masonry();
    } else {
      this.inject_new_items();
    }
    this.el.style.height = grid['_layout']['styles']['height'];
  },
};

