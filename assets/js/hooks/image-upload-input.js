const pica = require('pica')();

export const imageToBlob = (imageFile, height) => {
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.addEventListener('load', (e) => {
      const img = new Image();
      img.crossOrigin = 'Anonymous';
      img.onload = function () {
        const canvas = document.createElement('canvas');
        canvas.height = Math.min(height, this.naturalHeight);
        canvas.width = (canvas.height * this.naturalWidth) / this.naturalHeight;

        pica
          .resize(this, canvas)
          .then((result) => pica.toBlob(result, 'image/jpeg', 0.9))
          .then(resolve);
      };
      img.src = reader.result;
    });
    reader.readAsDataURL(imageFile);
  });
};

export default {
  mounted() {
    const { target, resizeHeight, uploadFolder } = this.el.dataset;
    const button = this.el.querySelector('.upload-button');
    const hiddenInput = this.el.querySelector('input[type=hidden]');
    const fileInput = this.el.querySelector('input[type=file]');

    button.onclick = () => fileInput.click();

    this.el.ondrop = (event) => {
      event.preventDefault();
      const file = event.dataTransfer.files[0];
      if (file) {
        uploadImage(file);
      }
    };

    this.el.ondragover = (event) => {
      event.preventDefault();
    };

    const uploadImage = (file, onSuccess) => {
      const normalizedName = file.name
        .replace(/[^a-z0-9.-]/gi, '_')
        .replace(/\.\w+$/, '.jpg')
        .toLowerCase();
      this.pushEventTo(
        target,
        'get_signed_url',
        {
          name: normalizedName,
          type: 'image/jpeg',
          upload_folder: uploadFolder,
        },
        (reply) => {
          const formData = new FormData();
          const { url, fields } = reply;

          Object.entries(fields).forEach(([key, val]) =>
            formData.append(key, val)
          );
          imageToBlob(file, resizeHeight).then((blob) => {
            formData.append(
              'file',
              new File([blob], normalizedName, { type: 'image/jpeg' })
            );

            fetch(url, {
              method: 'POST',
              body: formData,
            })
              .then((response) => {
                if (response.status === 204) {
                  const uploadedUrl = `${url}/${fields.key}`;
                  this.pushEventTo(target, 'upload_finished', {
                    url: uploadedUrl,
                  });
                  hiddenInput.value = uploadedUrl;
                  hiddenInput.dispatchEvent(
                    new Event('input', { bubbles: true })
                  );
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

    fileInput.setAttribute('accept', 'image/jpeg,image/png');
    fileInput.onchange = () => {
      const file = fileInput.files[0];
      if (file) {
        uploadImage(file);
      }
    };
  },
};
