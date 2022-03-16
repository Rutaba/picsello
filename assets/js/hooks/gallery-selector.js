export default {
  mounted() {
    this.handleEvent('click', ({id}) => {
      console.log(id)
      
    });
  },
};
