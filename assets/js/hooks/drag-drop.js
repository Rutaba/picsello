export default {
    mounted() {
        let dropArea = document.getElementById(this.el.id);
        [("dragenter", "dragover", "dragleave", "drop")].forEach((eventName) => {
            dropArea.addEventListener(eventName, preventDefaults, false);
        });
        function preventDefaults(e) {
            e.preventDefault();
        }
        ["dragenter", "dragover"].forEach((eventName) => {
            dropArea.addEventListener(eventName, highlight, false);
        });

        ["dragleave", "drop"].forEach((eventName) => {
            dropArea.addEventListener(eventName, unhighlight, false);
        });
        function highlight(e) {
            dropArea.classList.add("active");
        }

        function unhighlight(e) {
            dropArea.classList.remove("active");
        }
    },
};
