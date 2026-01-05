/* ----------------------------------------------------------------------------
 * Two Factor HTTP client.
 * ---------------------------------------------------------------------------- */

App.Http.TwoFactor = (function () {
    function validate(code, remember) {
        const url = App.Utils.Url.siteUrl('two_factor/validate');
        const data = {
            csrf_token: vars('csrf_token'),
            code,
            remember: remember ? 1 : 0,
        };
        return $.post(url, data);
    }

    function setupInit() {
        const url = App.Utils.Url.siteUrl('two_factor/setup_init');
        const data = { csrf_token: vars('csrf_token') };
        return $.post(url, data);
    }

    function setupEnable(code) {
        const url = App.Utils.Url.siteUrl('two_factor/setup_enable');
        const data = { csrf_token: vars('csrf_token'), code };
        return $.post(url, data);
    }

    function setupDisable() {
        const url = App.Utils.Url.siteUrl('two_factor/setup_disable');
        const data = { csrf_token: vars('csrf_token') };
        return $.post(url, data);
    }

    function regenerateRecoveryCodes() {
        const url = App.Utils.Url.siteUrl('two_factor/regenerate_recovery_codes');
        const data = { csrf_token: vars('csrf_token') };
        return $.post(url, data);
    }

    function devices() {
        const url = App.Utils.Url.siteUrl('two_factor/devices');
        return $.get(url);
    }

    function revokeDevice(deviceHash) {
        const url = App.Utils.Url.siteUrl('two_factor/revoke_device');
        const data = { csrf_token: vars('csrf_token'), device_hash: deviceHash };
        return $.post(url, data);
    }

    return {
        validate,
        setupInit,
        setupEnable,
        setupDisable,
        regenerateRecoveryCodes,
        devices,
        revokeDevice,
    };
})();



