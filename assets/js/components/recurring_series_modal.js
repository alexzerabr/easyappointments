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
 * Recurring series modal component.
 *
 * This module implements the recurring series edit/delete modal functionality.
 */
App.Components.RecurringSeriesModal = (function () {
    const $recurringSeriesModal = $('#recurring-series-modal');
    const $recurringDeleteModal = $('#recurring-delete-modal');
    const $editThisAppointment = $('#edit-this-appointment');
    const $editFutureAppointments = $('#edit-future-appointments');
    const $editAllAppointments = $('#edit-all-appointments');
    const $deleteThisAppointment = $('#delete-this-appointment');
    const $deleteFutureAppointments = $('#delete-future-appointments');
    const $deleteAllAppointments = $('#delete-all-appointments');

    let editCallback = null;
    let deleteCallback = null;

    /**
     * Add event listeners for recurring series modal.
     */
    function addEventListeners() {
        /**
         * Event: Edit This Appointment Button "Click"
         */
        $editThisAppointment.on('click', () => {
            const scope = $editThisAppointment.data('action');
            $recurringSeriesModal.modal('hide');
            if (editCallback) {
                editCallback(scope);
            }
        });

        /**
         * Event: Edit Future Appointments Button "Click"
         */
        $editFutureAppointments.on('click', () => {
            const scope = $editFutureAppointments.data('action');
            $recurringSeriesModal.modal('hide');
            if (editCallback) {
                editCallback(scope);
            }
        });

        /**
         * Event: Edit All Appointments Button "Click"
         */
        $editAllAppointments.on('click', () => {
            const scope = $editAllAppointments.data('action');
            $recurringSeriesModal.modal('hide');
            if (editCallback) {
                editCallback(scope);
            }
        });

        /**
         * Event: Delete This Appointment Button "Click"
         */
        $deleteThisAppointment.on('click', () => {
            const scope = $deleteThisAppointment.data('action');
            $recurringDeleteModal.modal('hide');
            if (deleteCallback) {
                deleteCallback(scope);
            }
        });

        /**
         * Event: Delete Future Appointments Button "Click"
         */
        $deleteFutureAppointments.on('click', () => {
            const scope = $deleteFutureAppointments.data('action');
            $recurringDeleteModal.modal('hide');
            if (deleteCallback) {
                deleteCallback(scope);
            }
        });

        /**
         * Event: Delete All Appointments Button "Click"
         */
        $deleteAllAppointments.on('click', () => {
            const scope = $deleteAllAppointments.data('action');
            $recurringDeleteModal.modal('hide');
            if (deleteCallback) {
                deleteCallback(scope);
            }
        });
    }

    /**
     * Show the edit recurring series modal.
     *
     * @param {Function} callback - Callback function to be called when user selects a scope.
     */
    function showEditModal(callback) {
        editCallback = callback;
        $recurringSeriesModal.modal('show');
    }

    /**
     * Show the delete recurring series modal.
     *
     * @param {Function} callback - Callback function to be called when user selects a scope.
     */
    function showDeleteModal(callback) {
        deleteCallback = callback;
        $recurringDeleteModal.modal('show');
    }

    /**
     * Hide the edit modal.
     */
    function hideEditModal() {
        $recurringSeriesModal.modal('hide');
    }

    /**
     * Hide the delete modal.
     */
    function hideDeleteModal() {
        $recurringDeleteModal.modal('hide');
    }

    /**
     * Initialize the module.
     */
    function initialize() {
        addEventListeners();
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {
        initialize,
        showEditModal,
        showDeleteModal,
        hideEditModal,
        hideDeleteModal,
    };
})();


