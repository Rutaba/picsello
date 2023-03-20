import Quill from 'quill';
import { imageToBlob } from './image-upload-input';

const Link = Quill.import('formats/link');

class CustomLink extends Link {
  static create(value) {
    let node = super.create(value);
    value = this.sanitize(value);
    if (!value.startsWith('http')) {
      value = `https://${value}`;
    }
    node.setAttribute('href', value);
    return node;
  }
}

Quill.register(CustomLink, true);

const SizeStyle = Quill.import('attributors/style/size');
SizeStyle.whitelist = ['10px', '18px', '32px'];
Quill.register(SizeStyle, true);

const BlockEmbed = Quill.import('blots/block/embed');

class ImageBlot extends BlockEmbed {
  static create(value) {
    const node = super.create();
    node.setAttribute('src', value.url);
    node.style.maxWidth = '100%';
    node.style.marginLeft = 'auto';
    node.style.marginRight = 'auto';
    return node;
  }

  static value(node) {
    return {
      url: node.getAttribute('src'),
    };
  }
}
ImageBlot.blotName = 'image';
ImageBlot.tagName = 'img';

Quill.register(ImageBlot, true);

export default {
  mounted() {
    const editorEl = this.el.querySelector('.editor');
    const {
      placeholder = 'Compose message...',
      textFieldName,
      htmlFieldName,
      enableSize,
      enableImage,
      target,
    } = this.el.dataset;
    const textInput = textFieldName
      ? this.el.querySelector(`input[name="${textFieldName}"]`)
      : null;
    const htmlInput = htmlFieldName
      ? this.el.querySelector(`input[name="${htmlFieldName}"]`)
      : null;
    const fileInput = this.el.querySelector('input[type=file]');
    const quillSourceInput = this.el.querySelector('input[name*=quill_source]');

    const toolbarOptions = [
      'bold',
      'italic',
      'underline',
      { list: 'bullet' },
      { list: 'ordered' },
      'link',
    ];

    if (enableSize !== undefined) {
      toolbarOptions.unshift({ size: ['10px', false, '18px', '32px'] });
    }

    if (enableImage !== undefined) {
      toolbarOptions.push('image');
    }

    const quill = new Quill(editorEl, {
      modules: {
        toolbar: {
          container: toolbarOptions,
          handlers: { image: () => fileInput.click() },
        },
      },
      placeholder,
      theme: 'snow',
    });

    const uploadImage = (file, onSuccess) => {
      const normalizedName = file.name
        .replace(/[^a-z0-9.-]/gi, '_')
        .replace(/\.\w+$/, '.jpg')
        .toLowerCase();
      this.pushEventTo(
        target,
        'get_signed_url',
        { name: normalizedName, type: 'image/jpeg' },
        (reply) => {
          const formData = new FormData();
          const { url, fields } = reply;

          Object.entries(fields).forEach(([key, val]) =>
            formData.append(key, val)
          );

          imageToBlob(file, 600).then((blob) => {
            formData.append(
              'file',
              new File([blob], normalizedName, { type: 'image/jpeg' })
            );

            fetch(url, { method: 'POST', body: formData })
              .then((response) => {
                if (response.status === 204) {
                  onSuccess(`${url}/${fields.key}`);
                } else {
                  alert('Something went wrong!');
                }
              })
              .catch(() => {
                alert('Something went wrong!');
              });
          });
        }
      );
    };

    if (fileInput) {
      fileInput.setAttribute('accept', 'image/jpeg,image/png');
      fileInput.onchange = () => {
        const file = fileInput.files[0];
        if (file) {
          uploadImage(file, (url) => {
            const range = quill.getSelection(true);
            quill.insertText(range.index, '\n', Quill.sources.USER);
            quill.insertEmbed(
              range.index,
              'image',
              { url },
              Quill.sources.USER
            );
            quill.setSelection(range.index + 2, Quill.sources.SILENT);
          });
        }
      };
    }

    function textChange(_delta, _oldDelta, source) {
      htmlInput.value = quill.root.innerHTML;
      const text = quill.getText();

      if (text && text.trim().length === 0) {
        htmlInput.value = '';
      }
      htmlInput.dispatchEvent(new Event('input', { bubbles: true }));

      if (textInput) {
        textInput.value = text;
        textInput.dispatchEvent(new Event('input', { bubbles: true }));
      }

      if (quillSourceInput) {
        quillSourceInput.value = source || '';
      }
    }

    quill.on('text-change', textChange);

    this.handleEvent('quill:update', ({ html }) => {
      quill.clipboard.dangerouslyPasteHTML(html, '');
      textChange();
    });

    quill.clipboard.dangerouslyPasteHTML(htmlInput.value, '');
  },
};
  
export const ClearQuillInput = {
  mounted() {
    this.el.addEventListener('click', () => {
      const element = document.querySelector('.ql-editor');
      element.innerHTML = '';
      element.classList.add('ql-blank');
    });
  },
};
