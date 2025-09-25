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
 * WhatsApp Integration HTTP client.
 *
 * This module implements the WhatsApp integration related HTTP requests.
 */
App.Http.WhatsAppIntegration = (function () {
    /**
     * Save WhatsApp integration settings.
     *
     * @param {Array} whatsappSettings
     *
     * @return {Object}
     */
    function save(whatsappSettings) {
        const url = App.Utils.Url.siteUrl('whatsapp_integration/save');

        const data = {
            csrf_token: vars('csrf_token'),
            whatsapp_settings: whatsappSettings,
        };

        return $.post(url, data);
    }

    /**
     * Generate authentication token.
     *
     * @param {String} secretKey
     *
     * @return {Object}
     */
    function generateToken(secretKey) {
        const url = App.Utils.Url.siteUrl('whatsapp_integration/generate_token');

        const data = {
            csrf_token: vars('csrf_token'),
            secret_key: secretKey,
        };

        return $.post(url, data);
    }

    /**
     * Test connectivity to WPPConnect server.
     *
     * @return {Object}
     */
    function testConnectivity() {
        const url = App.Utils.Url.siteUrl('whatsapp_integration/test_connectivity');

        const data = {
            csrf_token: vars('csrf_token'),
        };

        return $.post(url, data);
    }

    /**
     * Start WhatsApp session.
     *
     * @param {Boolean} waitQrCode
     *
     * @return {Object}
     */
    function startSession(waitQrCode = true) {
        const url = App.Utils.Url.siteUrl('whatsapp_integration/start_session');

        const data = {
            csrf_token: vars('csrf_token'),
            waitQrCode: waitQrCode,
        };

        return $.post(url, data);
    }

    /**
     * Get session status.
     *
     * @return {Object}
     */
    function getStatus() {
        const url = App.Utils.Url.siteUrl('whatsapp_integration/get_status');

        const data = {
            csrf_token: vars('csrf_token'),
        };

        return $.get(url, data);
    }

    /**
     * Close WhatsApp session.
     *
     * @return {Object}
     */
    function closeSession() {
        const url = App.Utils.Url.siteUrl('whatsapp_integration/close_session');

        const data = {
            csrf_token: vars('csrf_token'),
        };

        return $.post(url, data);
    }

    /**
     * Logout from WhatsApp session.
     *
     * @return {Object}
     */
    function logoutSession() {
        const url = App.Utils.Url.siteUrl('whatsapp_integration/logout_session');

        const data = {
            csrf_token: vars('csrf_token'),
        };

        return $.post(url, data);
    }

    /**
     * Get message logs.
     *
     * @param {Object} filters
     *
     * @return {Object}
     */
    function getMessageLogs(filters = {}) {
        const url = App.Utils.Url.siteUrl('whatsapp_integration/get_message_logs');

        const data = {
            csrf_token: vars('csrf_token'),
            ...filters,
        };

        return $.post(url, data);
    }

    /**
     * Send manual WhatsApp message.
     *
     * @param {Number} appointmentId
     * @param {Number|null} templateId
     * @param {String|null} customMessage
     *
     * @return {Object}
     */
    function sendMessage(appointmentId, templateId = null, customMessage = null) {
        const url = App.Utils.Url.siteUrl('whatsapp_integration/send_message');

        const data = {
            csrf_token: vars('csrf_token'),
            appointment_id: appointmentId,
            template_id: templateId,
            custom_message: customMessage,
        };

        return $.post(url, data);
    }

    return {
        save,
        generateToken,
        testConnectivity,
        startSession,
        getStatus,
        closeSession,
        logoutSession,
        getMessageLogs,
        sendMessage,
    };
})();
