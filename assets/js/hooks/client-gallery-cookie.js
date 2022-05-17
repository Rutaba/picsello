export default {
  mounted() {
    const { el } = this;
    const name = el.dataset.name;
    const gallery = document.querySelector('#gallery');
    if(getCookie(name)) {
      gallery.classList.remove("sm:hidden");
    } else {
      el.classList.remove("hidden");
    }
  },
  updated() {
    const { el } = this;
    if(el.dataset.active == 'true') {
      setCookie(el.dataset.name, true, el.dataset.max_age);
    }
  },
};

function setCookie(name, value, days) {
  var expires = "";
  if (days) {
      const date = new Date();
      date.setDate(date.getDate() + days);
      expires = `; Expires=${date.toUTCString()}`;
  }
  document.cookie = name + "=" + (value || "")  + expires + "; path=/";
}

function getCookie(name) {
  const nameEQ = name + "=";
  const cookies = document.cookie.split(';');
  for(var i=0;i < cookies.length;i++) {
      var cookie = cookies[i];
      while (cookie.charAt(0)==' ') cookie = cookie.substring(1, cookie.length);
      if (cookie.indexOf(nameEQ) == 0) return cookie.substring(nameEQ.length, cookie.length);
  }
  return false;
}