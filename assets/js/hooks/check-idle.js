let time;

export default {
  checkInactivity(idleTimeout, component) {
    window.onload = resetTimer;
    document.onmousemove = resetTimer;
    document.onkeypress = resetTimer;

    function handlePopup() {
      component.pushEvent('fire_idle_popup', {});
    }

    function resetTimer() {
      clearTimer();
      time = setTimeout(handlePopup, idleTimeout);
    }

    function clearTimer() {
      console.log(time);
      clearTimeout(time);
    }
  },
  mounted() {
    const { idleTimeout } = this.el.dataset;
    this.checkInactivity(parseInt(idleTimeout || 180000), this);
  },
  destroyed() {
    window.onload = null;
    document.onmousemove = null;
    document.onkeypress = null;
    clearTimeout(time);
  },
};
