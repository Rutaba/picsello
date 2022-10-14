/**
 * pushes event load-more when threshold scrolled
 *
 * @see https://github.com/chrismccord/phoenix_live_view_example/blob/74167e3617a09dc30fccdb88cba52d1861b1199f/assets/js/app.js
 */

function scrollAt() {
  const scrollTop =
    document.documentElement.scrollTop || document.body.scrollTop;
  const scrollHeight =
    document.documentElement.scrollHeight || document.body.scrollHeight;
  const clientHeight = document.documentElement.clientHeight;

  return (scrollTop / (scrollHeight - clientHeight)) * 100;
}

const InfiniteScroll = {
  page() {
    return this.el.dataset.page;
  },
  mounted() {
    this.pending = this.page();
    const threshold = parseFloat(this.el.dataset.threshold);
    window.addEventListener('scroll', () => {
      if (this.pending == this.page() && scrollAt() > threshold) {
        this.pending = this.page() + 1;
        this.pushEvent('load-more', {});
      }
    });
  },
  reconnected() {
    this.pending = this.page();
  },
  updated() {
    this.pending = this.page();
  },
};
export default InfiniteScroll;
