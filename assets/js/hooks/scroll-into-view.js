export default {
  mounted() {
    var element = document.getElementById("gallery-anchor");
    console.log(element)
    if(element){
      var offsetPosition = element.getBoundingClientRect().top + window.pageYOffset - 70;

      setTimeout(() => {
        window.scrollTo({ top: offsetPosition, behavior: 'smooth' });
      }, 100);  
    }
  },  
};
