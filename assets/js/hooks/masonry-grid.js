import Masonry from "masonry-layout";

export default {
  updated() {
    const grid = document.querySelector(".masonry");
    if (grid) {
      grid.classList.remove('hidden');

      const options = {
        itemSelector: ".item",
        columnWidth: 309,
        gutter: 20,
        fitWidth: true,
      };
      setTimeout( () => {
        new Masonry(grid, options);
      }, 100);
    }
  }
};
