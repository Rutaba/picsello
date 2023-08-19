export default {
  checkInactivity(idleTimeout, component) {
    let time;
    window.onload = resetTimer;
    document.onmousemove = resetTimer;
    document.onkeypress = resetTimer;
    function handlePopup() {
      component.pushEvent('fire_idle_popup', {});
    }
    function resetTimer() {
      clearTimeout(time);
      time = setTimeout(handlePopup, idleTimeout);
    }
  },
  mounted() {
    const { idleTimeout } = this.el.dataset;
    this.checkInactivity(parseInt(idleTimeout || 180000), this);
  },
};
