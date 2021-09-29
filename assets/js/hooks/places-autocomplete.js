const PlacesAutocomplete = {
  mounted() {
    const metaTag = [
      ...document.head.getElementsByTagName('meta'),
    ].find(({ name }) => name == 'google-maps-api-key');

    if(!metaTag) return;

    const input = this.el;

    const setAutocomplete = () => {
      new window.google.maps.places.Autocomplete(input);

      setTimeout(() => {
        // move .pac-container from document.body to .autocomplete-wrapper so it scrolls together with the input
        input.parentElement
          .querySelector('.autocomplete-wrapper')
          .append(document.querySelector('.pac-container'));
      }, 300);
    };

    if (window['googleMapsInitialized']) {
      setAutocomplete();
    } else {
      window['googleMapsInitAutocomplete'] = function () {
        window['googleMapsInitialized'] = true;
        setAutocomplete();
      };

      const googleSrc = `https://maps.googleapis.com/maps/api/js?key=${metaTag.content}&libraries=places&callback=googleMapsInitAutocomplete`;

      const scriptNode = document.createElement('script');
      scriptNode.setAttribute('src', googleSrc);
      document.head.append(scriptNode);
    }
  },
};

export default PlacesAutocomplete;
