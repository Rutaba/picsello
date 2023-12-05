export default {
  mounted() {
    console.log('mounting stripe elements');
    const parentForm = this.el.closest('form');
    const submitBtn = document.getElementById('payment-element-submit');
    const { publishableKey, name, email, returnUrl, type } = this.el.dataset;

    const stripe = Stripe(publishableKey, {
      apiVersion: '2020-08-27',
    });

    // Set up Stripe.js and Elements to use in checkout form
    const elements =
      type === 'setup'
        ? stripe.elements({
            mode: 'setup',
            currency: 'usd',
            setupFutureUsage: 'off_session',
          })
        : stripe.elements({
            mode: 'subscription',
            amount: 24000,
            currency: 'usd',
            setupFutureUsage: 'off_session',
          });

    // Create and mount the Payment Element
    const paymentElement = elements.create('payment');
    paymentElement.mount(this.el.querySelector('#payment-element'));

    const addressElement = elements.create('address', {
      mode: 'billing',
      defaultValues: {
        name,
        email,
      },
    });
    addressElement.mount(this.el.querySelector('#address-element'));

    parentForm.addEventListener('submit', async (event) => {
      // We don't want to let default form submission happen here,
      // which would let changeset validate the form and handle the
      // submission for us, which in this case we don't want
      event.preventDefault();

      // Prevent multiple form submissions
      if (submitBtn.disabled) {
        return;
      }

      // Disable form submission while loading
      this.pushEvent('stripe-elements-loading', {});

      // Trigger form validation and wallet collection
      const { error: submitError } = await elements.submit();
      if (submitError) {
        console.log(submitError);
        this.pushEvent('stripe-elements-error', { error: submitError });
        return;
      }

      const address = await addressElement.getValue().then(function (result) {
        if (result.complete) {
          return result;
          // Allow user to proceed to the next step
          // Optionally, use value to store the address details
        } else {
          return {};
        }
      });

      this.pushEvent('stripe-elements-create', {
        address,
      });

      this.handleEvent(
        'stripe-elements-confirm',
        async ({
          type,
          client_secret,
          state,
          country,
          promotion_code,
          subscription_id,
        }) => {
          const confirmIntent =
            type === 'setup' ? stripe.confirmSetup : stripe.confirmPayment;

          // Confirm the Intent using the details collected by the Payment Element
          const { error } = await confirmIntent({
            elements,
            clientSecret: client_secret,
            confirmParams: {
              return_url: `${returnUrl}?state=${state}&country=${country}&promotion_code=${promotion_code}`,
            },
            redirect: 'if_required',
          });

          if (error) {
            console.log(error);
            this.pushEvent('stripe-elements-error', { error });
          } else {
            this.pushEvent('stripe-elements-success', {
              state,
              country,
              promotion_code,
              subscription_id,
            });

            window.location = `${returnUrl}?state=${state}&country=${country}&promotion_code=${promotion_code}&redirect_status=succeeded`;
          }
        }
      );
    });
  },
};
