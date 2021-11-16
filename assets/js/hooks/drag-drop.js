export default {
    mounted() {
        const {el} = this;
        const dropArea = document.getElementById(el.id);
        const content = dropArea.closest('.dragDrop__wrapper');

        const preventDefaults = (e) => {
            e.preventDefault();
            e.stopPropagation();
        }
        const highlight = () => dropArea.classList.add("active");
        const unhighlight = () => dropArea.classList.remove("active");

        [("dragenter", "dragover", "dragleave", "drop")].forEach((eventName) => {
            dropArea.addEventListener(eventName, preventDefaults, false);
        });

        ["dragenter", "dragover"].forEach((eventName) => {
            dropArea.addEventListener(eventName, highlight, false);
        });

        ["dragleave", "drop"].forEach((eventName) => {
            dropArea.addEventListener(eventName, unhighlight, false);
        });
    },

    updated() {
        const errorElements = document.querySelectorAll('.photoUploadingIsFailed');
        const errorElementsArray = Array.from(errorElements);

        if (errorElementsArray.length) {
            errorElementsArray.forEach(el => document.getElementById(el.dataset.name)
                .querySelector('progress').style.display = 'none');
        }
    },
};
