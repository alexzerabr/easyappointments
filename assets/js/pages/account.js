/* ----------------------------------------------------------------------------
 * Easy!Appointments - Online Appointment Scheduler
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.5.0
 * ---------------------------------------------------------------------------- */

/**
 * Account page.
 *
 * This module implements the functionality of the account page.
 */
App.Pages.Account = (function () {
    const $userId = $('#user-id');
    const $firstName = $('#first-name');
    const $lastName = $('#last-name');
    const $email = $('#email');
    const $mobileNumber = $('#mobile-number');
    const $phoneNumber = $('#phone-number');
    const $address = $('#address');
    const $city = $('#city');
    const $state = $('#state');
    const $zipCode = $('#zip-code');
    const $notes = $('#notes');
    const $language = $('#language');
    const $timezone = $('#timezone');
    const $username = $('#username');
    const $password = $('#password');
    const $retypePassword = $('#retype-password');
    const $calendarView = $('#calendar-view');
    const notifications = $('#notifications');
    const $saveSettings = $('#save-settings');
    const $footerUserDisplayName = $('#footer-user-display-name');
    const $twoFactorToggle = $('#two-factor-enabled');
    const $twoFactorQr = $('#two-factor-qr');
    const $twoFactorQrContainer = $('#two-factor-qr-container');
    const $twoFactorCode = $('#two-factor-code');
    const $twoFactorEnableBtn = $('#two-factor-enable');
    const $twoFactorDisableBtn = $('#two-factor-disable');
    const $twoFactorCodesWrap = $('#two-factor-codes-wrap');
    const $twoFactorCodesList = $('#two-factor-codes');
    const $twoFactorRegenerate = $('#two-factor-regenerate');
    const $twoFactorDevicesList = $('#two-factor-devices-list');

    /**
     * Check if the form has invalid values.
     *
     * @return {Boolean}
     */
    function isInvalid() {
        try {
            $('#account .is-invalid').removeClass('is-invalid');

            // Validate required fields.

            let missingRequiredFields = false;

            $('#account .required').each((index, requiredField) => {
                const $requiredField = $(requiredField);

                if (!$requiredField.val()) {
                    $requiredField.addClass('is-invalid');
                    missingRequiredFields = true;
                }
            });

            if (missingRequiredFields) {
                throw new Error(lang('fields_are_required'));
            }

            // Validate passwords (if values provided).

            if ($password.val() && $password.val() !== $retypePassword.val()) {
                $password.addClass('is-invalid');
                $retypePassword.addClass('is-invalid');
                throw new Error(lang('passwords_mismatch'));
            }

            // Validate user email.

            const emailValue = $email.val();

            if (!App.Utils.Validation.email(emailValue)) {
                $email.addClass('is-invalid');
                throw new Error(lang('invalid_email'));
            }

            if ($username.hasClass('is-invalid')) {
                throw new Error(lang('username_already_exists'));
            }

            return false;
        } catch (error) {
            App.Layouts.Backend.displayNotification(error.message);
            return true;
        }
    }

    /**
     * Apply the account values to the form.
     *
     * @param {Object} account
     */
    function deserialize(account) {
        $userId.val(account.id);
        $firstName.val(account.first_name);
        $lastName.val(account.last_name);
        $email.val(account.email);
        $mobileNumber.val(account.mobile_number);
        $phoneNumber.val(account.phone_number);
        $address.val(account.address);
        $city.val(account.city);
        $state.val(account.state);
        $zipCode.val(account.zip_code);
        $notes.val(account.notes);
        $language.val(account.language);
        $timezone.val(account.timezone);
        $username.val(account.settings.username);
        $password.val('');
        $retypePassword.val('');
        $calendarView.val(account.settings.calendar_view);
        notifications.prop('checked', Boolean(Number(account.settings.notifications)));

        // 2FA state (if backend exposes settings.two_factor_enabled)
        if (account.settings && account.settings.two_factor_enabled !== undefined) {
            const enabled = Number(account.settings.two_factor_enabled) === 1;
            $twoFactorToggle.prop('checked', enabled).prop('disabled', false);
            $twoFactorDisableBtn.toggleClass('d-none', !enabled);
            $twoFactorEnableBtn.toggleClass('d-none', enabled);
            $twoFactorCodesWrap.toggleClass('d-none', true);
        }
    }

    /**
     * Get the account information from the form.
     *
     * @return {Object}
     */
    function serialize() {
        return {
            id: $userId.val(),
            first_name: $firstName.val(),
            last_name: $lastName.val(),
            email: $email.val(),
            mobile_number: $mobileNumber.val(),
            phone_number: $phoneNumber.val(),
            address: $address.val(),
            city: $city.val(),
            state: $state.val(),
            zip_code: $zipCode.val(),
            notes: $notes.val(),
            language: $language.val(),
            timezone: $timezone.val(),
            settings: {
                username: $username.val(),
                password: $password.val() || undefined,
                calendar_view: $calendarView.val(),
                notifications: Number(notifications.prop('checked')),
            },
        };
    }

    /**
     * Save the account information.
     */
    function onSaveSettingsClick() {
        if (isInvalid()) {
            App.Layouts.Backend.displayNotification(lang('user_settings_are_invalid'));

            return;
        }

        const account = serialize();

        App.Http.Account.save(account).done(() => {
            App.Layouts.Backend.displayNotification(lang('settings_saved'));

            $footerUserDisplayName.text('Hello, ' + $firstName.val() + ' ' + $lastName.val() + '!');
        });
    }

    // 2FA: start setup flow -> get secret and display QR
    function onTwoFactorEnableInit() {
        App.Http.TwoFactor.setupInit()
            .done((response) => {
                if (!response.success) { return; }
                const otpauth = response.otpauth;
                const secret = response.secret;
                
                if (response.qr_data_url) {
                    // Server-side QR code generation successful
                    $twoFactorQrContainer.addClass('d-none');
                    $twoFactorQr.attr('src', response.qr_data_url).removeClass('d-none');
                } else if (typeof QRCode !== 'undefined') {
                    // Client-side QR code generation
                    try {
                        $twoFactorQr.addClass('d-none');
                        $twoFactorQrContainer.empty();
                        const elem = $twoFactorQrContainer.get(0);
                        // qrcode.js (davidshimjs) API: new QRCode(element, { text, width, height })
                        new QRCode(elem, { text: otpauth, width: 200, height: 200, correctLevel: QRCode.CorrectLevel.L });
                        $twoFactorQrContainer.removeClass('d-none');
                    } catch (e) {
                        console.error('QRCode generation failed:', e);
                        $twoFactorQr.addClass('d-none');
                        $twoFactorQrContainer.addClass('d-none');
                        // Show manual setup option
                        if (secret) {
                            App.Layouts.Backend.displayNotification('QR code could not be generated. Manual secret: ' + secret);
                        }
                    }
                } else {
                    // QRCode library not loaded - show manual setup
                    console.error('QRCode library not loaded. Check that qrcode.min.js is available.');
                    $twoFactorQr.addClass('d-none');
                    $twoFactorQrContainer.addClass('d-none');
                    if (secret) {
                        App.Layouts.Backend.displayNotification('Please enter this secret manually in your authenticator app: ' + secret);
                    }
                }
                $twoFactorCode.val('');
                $twoFactorEnableBtn.removeClass('d-none');
            })
            .fail((xhr) => {
                App.Layouts.Backend.displayNotification('Failed to initialize 2FA setup. Please try again.');
            });
    }

    // 2FA: verify code and enable
    function onTwoFactorEnableConfirm() {
        const code = $twoFactorCode.val();
        if (!code) { return; }
        App.Http.TwoFactor.setupEnable(code)
            .done((response) => {
                if (response.success) {
                    $twoFactorToggle.prop('checked', true);
                    $twoFactorDisableBtn.removeClass('d-none');
                    $twoFactorEnableBtn.addClass('d-none');
                    $twoFactorCodesList.empty();
                    (response.recovery_codes || []).forEach((c) => {
                        $('<li/>').text(c).appendTo($twoFactorCodesList);
                    });
                    $twoFactorCodesWrap.removeClass('d-none');
                    refreshDevices();
                    App.Layouts.Backend.displayNotification(lang('settings_saved'));
                }
            })
            .fail((xhr) => {
                let message = 'Failed to enable 2FA. Please check your code and try again.';
                if (xhr.responseJSON && xhr.responseJSON.message) {
                    message = xhr.responseJSON.message;
                }
                App.Layouts.Backend.displayNotification(message);
            });
    }

    // 2FA: disable
    function onTwoFactorDisable() {
        App.Http.TwoFactor.setupDisable()
            .done((response) => {
                if (response.success) {
                    $twoFactorToggle.prop('checked', false);
                    $twoFactorDisableBtn.addClass('d-none');
                    $twoFactorEnableBtn.removeClass('d-none');
                    $twoFactorQr.addClass('d-none').attr('src', '');
                    $twoFactorCodesWrap.addClass('d-none');
                    $twoFactorDevicesList.empty();
                    App.Layouts.Backend.displayNotification(lang('settings_saved'));
                }
            })
            .fail((xhr) => {
                App.Layouts.Backend.displayNotification('Failed to disable 2FA. Please try again.');
            });
    }

    function onTwoFactorRegenerate() {
        App.Http.TwoFactor.regenerateRecoveryCodes()
            .done((response) => {
                if (response.success) {
                    $twoFactorCodesList.empty();
                    (response.recovery_codes || []).forEach((c) => {
                        $('<li/>').text(c).appendTo($twoFactorCodesList);
                    });
                    $twoFactorCodesWrap.removeClass('d-none');
                    App.Layouts.Backend.displayNotification(lang('settings_saved'));
                }
            })
            .fail((xhr) => {
                App.Layouts.Backend.displayNotification('Failed to regenerate recovery codes. Please try again.');
            });
    }

    function refreshDevices() {
        App.Http.TwoFactor.devices()
            .done((response) => {
                if (!response.success) { return; }
                $twoFactorDevicesList.empty();
                (response.devices || []).forEach((d) => {
                    const $row = $('<div class="mb-1"/>');
                    const label = d.device_label || lang('two_factor_devices');
                    const last = d.last_used_datetime || '';
                    $('<span/>').text(label + ' — ' + last).appendTo($row);
                    const $btn = $('<button type="button" class="btn btn-link btn-sm ms-2"/>').text(lang('two_factor_revoke'));
                    $btn.on('click', function () {
                        App.Http.TwoFactor.revokeDevice(d.device_hash)
                            .done((r) => {
                                if (r.success) {
                                    refreshDevices();
                                    App.Layouts.Backend.displayNotification('Device revoked successfully.');
                                }
                            })
                            .fail((xhr) => {
                                App.Layouts.Backend.displayNotification('Failed to revoke device. Please try again.');
                            });
                    });
                    $btn.appendTo($row);
                    $row.appendTo($twoFactorDevicesList);
                });
                $twoFactorDevicesList.toggleClass('d-none', !(response.devices || []).length);
            })
            .fail((xhr) => {
                // Silent fail for device list refresh
            });
    }

    /**
     * Make sure the username is unique.
     */
    function onUsernameChange() {
        const username = $username.val();

        App.Http.Account.validateUsername(vars('user_id'), username).done((response) => {
            const isValid = response.is_valid;
            $username.toggleClass('is-invalid', !isValid);
            if (!isValid) {
                App.Layouts.Backend.displayNotification(lang('username_already_exists'));
            }
        });
    }

    /**
     * Initialize the page.
     */
    function initialize() {
        const account = vars('account');

        deserialize(account);

        $saveSettings.on('click', onSaveSettingsClick);

        $username.on('change', onUsernameChange);

        // 2FA bindings
        $twoFactorEnableBtn.on('click', onTwoFactorEnableConfirm);
        $('#two-factor-setup-init').on('click', onTwoFactorEnableInit);
        $twoFactorDisableBtn.on('click', onTwoFactorDisable);
        $twoFactorRegenerate.on('click', onTwoFactorRegenerate);
        refreshDevices();
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
