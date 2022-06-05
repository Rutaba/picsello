export default {
    mounted() {
        const {el} = this;
        const dropArea = document.getElementById(el.id);

        const preventDefaults = (e) => {
            e.preventDefault();
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
            errorElementsArray.forEach(el => {
                const tagName = document.getElementById(el.dataset.name)
                if(tagName){
                    tagName.querySelector('progress').style.display = 'none';
                }
            });
        }
    },
};
