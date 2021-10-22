import Muuri from "muuri";

export default {
  mounted() {
    const gridElement = document.querySelector("#muuri-grid");
    const opts = {
      layout: {
        fillGaps: true,
      },
      dragEnabled: true,
    };


    let grid = new Muuri(gridElement, opts);
    grid.on('dragReleaseEnd', (item) => {
      const order = grid.getItems().map(x => parseInt(x.getElement().id.slice(11)))
      this.set_change('photo_order', order);
      console.log(order)
    })

    this.grid = window.grid = grid;
  },
  set_change(name, value) {
    const field = document.querySelector(`#gallery_changes > input[name=${name}]`)
    if (field) {
      field.value = value
    }
  },
  inject_new_items() {
    const grid = this.grid;
    const addedItemsIds = grid.getItems().map(x => x.getElement().id);
    const allItems = document.querySelectorAll('#muuri-grid .item');
    const itemsToInject = Array.from(allItems).filter(x => !addedItemsIds.includes(x.id))

    grid.add(itemsToInject);
  },

  /**
   * Reconnect callback
   */
  reconnected(){
    // this.inject_new_items();
  },
  /**
   * Updated callback
   *
   * grid.getItems()[0].getElement().id
   */
  updated(){
    this.inject_new_items();
  }
};
