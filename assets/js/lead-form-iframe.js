import intlTelInput from 'intl-tel-input';

  const form = document?.querySelector('#client-form');
  const phone = document?.querySelector('#phone');
  phone.classList.add('w-full');
  
  
  const iti = intlTelInput(phone, {separateDialCode: true,
    nationalMode: false,
    separateDialCode: true,
    formatOnDisplay: true,
    utilsScript: "https://cdn.jsdelivr.net/npm/intl-tel-input@18.1.1/build/js/utils.js"
  });

  phone.addEventListener('keyup', (e) => {
    iti.setNumber(iti.getNumber())
   });

  form.addEventListener("submit", (e) => {
    phone.value = iti.getNumber()
  });

const jobTypes = document?.querySelectorAll('input[name="contact[job_type]"]');
jobTypes &&
  jobTypes.forEach((el) => {
    el.addEventListener('change', () => {
      const parent = el.parentElement;
      const icon = parent.querySelector('.rounded-full');

      jobTypes.forEach((el2) => {
        const parent = el2.parentElement;
        const icon = parent.querySelector('.rounded-full');
        parent.classList.remove('border-base-300', 'bg-base-200');
        icon.classList.remove('bg-base-300', 'text-white');
        icon.classList.add('bg-base-200');
      });

      parent.classList.add('border-base-300', 'bg-base-200');
      icon.classList.add('bg-base-300', 'text-white');
      icon.classList.remove('bg-base-200');
    });
  });
