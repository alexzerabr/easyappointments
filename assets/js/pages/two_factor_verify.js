/* ----------------------------------------------------------------------------
 * Two Factor verification page.
 * ---------------------------------------------------------------------------- */

App.Pages.TwoFactorVerify = (function () {
    const $form = $('#two-factor-form');
    const $code = $('#code');
    const $remember = $('#remember');

    function onSubmit(event) {
        event.preventDefault();

        const code = $code.val();
        const remember = $remember.is(':checked');

        if (!code) { return; }

        const $alert = $('.alert');
        $alert.addClass('d-none');

        App.Http.TwoFactor.validate(code, remember)
            .done((response) => {
                if (response.success) {
                    window.location.href = vars('dest_url') || App.Utils.Url.siteUrl('calendar');
                } else {
                    $alert.text(response.message || lang('invalid_totp_code'));
                    $alert.removeClass('d-none alert-success').addClass('alert-danger');
                }
            })
            .fail((xhr) => {
                let message = lang('invalid_totp_code');

                if (xhr.status === 429) {
                    message = 'Too many attempts. Please try again later.';
                } else if (xhr.status === 400 && xhr.responseJSON && xhr.responseJSON.message) {
                    message = xhr.responseJSON.message;
                } else if (xhr.status >= 500) {
                    message = 'Server error. Please try again later.';
                } else if (xhr.status === 0) {
                    message = 'Network error. Please check your connection.';
                }

                $alert.text(message);
                $alert.removeClass('d-none alert-success').addClass('alert-danger');
            });
    }

    $form.on('submit', onSubmit);

    return {};
})();



