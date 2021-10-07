export function Modal({ el, onOpen, onClose, isClosed }) {
  function clickOutside(e) {
    const isOutside = e.target.closest(`#${el.id}`) === null;

    if (isOutside) {
      close();
    }
  }

  function removeClickOutside() {
    document.body.removeEventListener('click', clickOutside);
  }

  function close() {
    onClose();
    removeClickOutside();
  }

  function open() {
    onOpen();
    document.body.addEventListener('click', clickOutside);
  }

  el.addEventListener('click', () => {
    if (isClosed()) {
      open();
    } else {
      close();
    }
  });

  function updated() {
    if (isClosed()) {
      removeClickOutside();
    }
  }

  return { destroyed: removeClickOutside, updated };
}

