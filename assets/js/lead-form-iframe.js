import IMask from 'imask';

const phone = document?.querySelector('#phone');

const jobTypes = document?.querySelectorAll('input[name="contact[job_type]"]');

phone && IMask(phone, { mask: '(000) 000-0000' });

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
