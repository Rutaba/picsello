function startCountdown(el, endTimestamp) {
  const interval = 1000; // Update every 1 second

  const countdownInterval = setInterval(() => {
    const now = Math.floor(Date.now() / 1000); // Current Unix timestamp in seconds
    const remainingSeconds = endTimestamp - now;

    if (remainingSeconds <= 0) {
      clearInterval(countdownInterval);
      console.log('Countdown complete!');
      return;
    }

    const days = Math.floor(remainingSeconds / 86400);
    const hours = Math.floor((remainingSeconds % 86400) / 3600);
    const minutes = Math.floor((remainingSeconds % 3600) / 60);
    const seconds = remainingSeconds % 60;

    el.innerHTML = `DEAL EXPIRES IN ${days}d ${hours}h ${minutes}m ${seconds}s`;
  }, interval);
}

export default {
  mounted() {
    const el = this.el;
    const { end } = el.dataset;
    startCountdown(el, end);
  },
  updated() {
    const el = this.el;
    const { end } = el.dataset;
    startCountdown(el, end);
  },
};
