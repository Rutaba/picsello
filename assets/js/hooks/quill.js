import Quill from 'quill';

export default {
  mounted() {
    const editorEl = this.el.querySelector('#editor');
    const textInput = this.el.querySelector('input[name*=text]');
    const htmlInput = this.el.querySelector('input[name*=html]');
    const quill = new Quill(editorEl, {
      modules: { toolbar: '#toolbar' },
      placeholder: 'Compose message...',
      theme: 'snow',
    });
    quill.on('text-change', () => {
      htmlInput.value = quill.root.innerHTML;
      textInput.value = quill.getText();
      textInput.dispatchEvent(new Event('input', { bubbles: true }));
    });
    quill.root.innerHTML = htmlInput.value;
  },
};
