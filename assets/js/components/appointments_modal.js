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
 * Appointments modal component.
 *
 * This module implements the appointments modal functionality.
 *
 * Old Name: BackendCalendarAppointmentsModal
 */
App.Components.AppointmentsModal = (function () {
    const $appointmentsModal = $('#appointments-modal');
    const $startDatetime = $('#start-datetime');
    const $endDatetime = $('#end-datetime');
    const $filterExistingCustomers = $('#filter-existing-customers');
    const $customerId = $('#customer-id');
    const $firstName = $('#first-name');
    const $lastName = $('#last-name');
    const $email = $('#email');
    const $phoneNumber = $('#phone-number');
    const $address = $('#address');
    const $city = $('#city');
    const $zipCode = $('#zip-code');
    const $language = $('#language');
    const $timezone = $('#timezone');
    const $customerNotes = $('#customer-notes');
    const $selectCustomer = $('#select-customer');
    const $saveAppointment = $('#save-appointment');
    const $appointmentId = $('#appointment-id');
    const $appointmentLocation = $('#appointment-location');
    const $appointmentStatus = $('#appointment-status');
    const $appointmentColor = $('#appointment-color');
    const $appointmentNotes = $('#appointment-notes');
    const $reloadAppointments = $('#reload-appointments');
    const $selectFilterItem = $('#select-filter-item');
    const $selectService = $('#select-service');
    const $selectProvider = $('#select-provider');
    const $insertAppointment = $('#insert-appointment');
    const $existingCustomersList = $('#existing-customers-list');
    const $newCustomer = $('#new-customer');
    const $customField1 = $('#custom-field-1');
    const $customField2 = $('#custom-field-2');
    const $customField3 = $('#custom-field-3');
    const $customField4 = $('#custom-field-4');
    const $customField5 = $('#custom-field-5');
    const $isRecurring = $('#is-recurring');
    const $recurringOptions = $('#recurring-options');
    const $specificWeekdaysGroup = $('#specific-weekdays-group');
    const $weekdayChecks = $('.weekday-check');
    const $recurringStartDate = $('#recurring-start-date');
    const $recurringEndDate = $('#recurring-end-date');
    const $recurringPreviewText = $('#recurring-preview-text');

    const moment = window.moment;

    /**
     * Update the displayed timezone.
     */
    function updateTimezone() {
        const providerId = $selectProvider.val();

        const provider = vars('available_providers').find(
            (availableProvider) => Number(availableProvider.id) === Number(providerId),
        );

        if (provider && provider.timezone) {
            $('.provider-timezone').text(vars('timezones')[provider.timezone]);
        }
    }

    /**
     * Add the component event listeners.
     */
    function addEventListeners() {
        /**
         * Event: Manage Appointments Dialog Save Button "Click"
         *
         * Stores the appointment changes or inserts a new appointment depending on the dialog mode.
         */
        $saveAppointment.on('click', () => {
            // Before doing anything the appointment data need to be validated.
            if (!App.Components.AppointmentsModal.validateAppointmentForm()) {
                return;
            }

            // ID must exist on the object in order for the model to update the record and not to perform
            // an insert operation.

            const startDateTimeObject = App.Utils.UI.getDateTimePickerValue($startDatetime);
            const startDatetime = moment(startDateTimeObject).format('YYYY-MM-DD HH:mm:ss');

            const endDateTimeObject = App.Utils.UI.getDateTimePickerValue($endDatetime);
            const endDatetime = moment(endDateTimeObject).format('YYYY-MM-DD HH:mm:ss');

            const appointment = {
                id_services: $selectService.val(),
                id_users_provider: $selectProvider.val(),
                start_datetime: startDatetime,
                end_datetime: endDatetime,
                location: $appointmentLocation.val(),
                color: App.Components.ColorSelection.getColor($appointmentColor),
                status: $appointmentStatus.val(),
                notes: $appointmentNotes.val(),
                is_unavailability: Number(false),
            };

            if ($appointmentId.val() !== '') {
                // Set the id value, only if we are editing an appointment.
                appointment.id = $appointmentId.val();
            }

            const customer = {
                first_name: $firstName.val(),
                last_name: $lastName.val(),
                email: $email.val(),
                phone_number: $phoneNumber.val(),
                address: $address.val(),
                city: $city.val(),
                zip_code: $zipCode.val(),
                language: $language.val(),
                timezone: $timezone.val(),
                notes: $customerNotes.val(),
                custom_field_1: $customField1.val(),
                custom_field_2: $customField2.val(),
                custom_field_3: $customField3.val(),
                custom_field_4: $customField4.val(),
                custom_field_5: $customField5.val(),
            };

            if ($customerId.val() !== '') {
                // Set the id value, only if we are editing an appointment.
                customer.id = $customerId.val();
                appointment.id_users_customer = customer.id;
            }

            // Define success callback.
            const successCallback = () => {
                // Display success message to the user.
                const message = $isRecurring.prop('checked')
                    ? lang('recurring_appointment_created')
                    : lang('appointment_saved');
                App.Layouts.Backend.displayNotification(message);

                // Close the modal dialog and refresh the calendar appointments.
                $appointmentsModal.find('.alert').addClass('d-none');
                $appointmentsModal.modal('hide');
                $reloadAppointments.trigger('click');
            };

            // Define error callback.
            const errorCallback = (response) => {
                let errorMessage = lang('service_communication_error');
                
                if (response && response.message) {
                    errorMessage = response.message;
                }
                
                $appointmentsModal.find('.modal-message').text(errorMessage);
                $appointmentsModal.find('.modal-message').addClass('alert-danger').removeClass('d-none');
                $appointmentsModal.find('.modal-body').scrollTop(0);
            };

            // Check if this is a recurring appointment
            if ($isRecurring.prop('checked') && !appointment.id) {
                // Save recurring appointment
                const recurringData = getRecurringData();
                
                const url = App.Utils.Url.siteUrl('calendar/save_recurring_appointment');
                
                $.ajax({
                    url: url,
                    type: 'POST',
                    data: {
                        csrf_token: vars('csrf_token'),
                        recurring_appointment: recurringData,
                        customer: customer,
                    },
                    dataType: 'json',
                    success: (response) => {
                        if (response.success) {
                            successCallback();
                        } else {
                            errorCallback(response);
                        }
                    },
                    error: () => {
                        errorCallback();
                    },
                });
            } else {
                // Save regular appointment
                App.Http.Calendar.saveAppointment(appointment, customer, successCallback, errorCallback);
            }
        });

        /**
         * Event: Insert Appointment Button "Click"
         *
         * When the user presses this button, the manage appointment dialog opens and lets the user create a new
         * appointment.
         */
        $insertAppointment.on('click', () => {
            $('.popover').remove();

            App.Components.AppointmentsModal.resetModal();

            // Set the selected filter item and find the next appointment time as the default modal values.
            if ($selectFilterItem.find('option:selected').attr('type') === 'provider') {
                const providerId = $('#select-filter-item').val();

                const providers = vars('available_providers').filter(
                    (provider) => Number(provider.id) === Number(providerId),
                );

                if (providers.length) {
                    $selectService.val(providers[0].services[0]).trigger('change');
                    $selectProvider.val(providerId);
                }
            } else if ($selectFilterItem.find('option:selected').attr('type') === 'service') {
                $selectService.find('option[value="' + $selectFilterItem.val() + '"]').prop('selected', true);
            } else {
                $selectService.find('option:first').prop('selected', true).trigger('change');
            }

            $selectProvider.trigger('change');

            const serviceId = $selectService.val();

            const service = vars('available_services').find(
                (availableService) => Number(availableService.id) === Number(serviceId),
            );

            const duration = service ? service.duration : 60;

            const startMoment = moment();

            const currentMin = parseInt(startMoment.format('mm'));

            if (currentMin > 0 && currentMin < 15) {
                startMoment.set({minutes: 15});
            } else if (currentMin > 15 && currentMin < 30) {
                startMoment.set({minutes: 30});
            } else if (currentMin > 30 && currentMin < 45) {
                startMoment.set({minutes: 45});
            } else {
                startMoment.add(1, 'hour').set({minutes: 0});
            }

            App.Utils.UI.setDateTimePickerValue($startDatetime, startMoment.toDate());
            App.Utils.UI.setDateTimePickerValue($endDatetime, startMoment.add(duration, 'minutes').toDate());

            // Display modal form.
            $appointmentsModal.find('.modal-header h3').text(lang('new_appointment_title'));

            $appointmentsModal.modal('show');
        });

        /**
         * Event: Pick Existing Customer Button "Click"
         *
         * @param {jQuery.Event} event
         */
        $selectCustomer.on('click', (event) => {
            if (!$existingCustomersList.is(':visible')) {
                $(event.target).find('span').text(lang('hide'));
                $existingCustomersList.empty();
                $existingCustomersList.slideDown('slow');
                $filterExistingCustomers.fadeIn('slow').val('');
                vars('customers').forEach((customer) => {
                    $('<div/>', {
                        'data-id': customer.id,
                        'text':
                            (customer.first_name || '[No First Name]') + ' ' + (customer.last_name || '[No Last Name]'),
                    }).appendTo($existingCustomersList);
                });
            } else {
                $existingCustomersList.slideUp('slow');
                $filterExistingCustomers.fadeOut('slow');
                $(event.target).find('span').text(lang('select'));
            }
        });

        /**
         * Event: Select Existing Customer From List "Click"
         *
         * @param {jQuery.Event}
         */
        $appointmentsModal.on('click', '#existing-customers-list div', (event) => {
            const customerId = $(event.target).attr('data-id');

            const customer = vars('customers').find((customer) => Number(customer.id) === Number(customerId));

            if (customer) {
                $customerId.val(customer.id);
                $firstName.val(customer.first_name);
                $lastName.val(customer.last_name);
                $email.val(customer.email);
                $phoneNumber.val(customer.phone_number);
                $address.val(customer.address);
                $city.val(customer.city);
                $zipCode.val(customer.zip_code);
                $language.val(customer.language);
                $timezone.val(customer.timezone);
                $customerNotes.val(customer.notes);
                $customField1.val(customer.custom_field_1);
                $customField2.val(customer.custom_field_2);
                $customField3.val(customer.custom_field_3);
                $customField4.val(customer.custom_field_4);
                $customField5.val(customer.custom_field_5);
            }

            $selectCustomer.trigger('click'); // Hide the list.
        });

        let filterExistingCustomersTimeout = null;

        /**
         * Event: Filter Existing Customers "Change"
         *
         * @param {jQuery.Event}
         */
        $filterExistingCustomers.on('keyup', (event) => {
            if (filterExistingCustomersTimeout) {
                clearTimeout(filterExistingCustomersTimeout);
            }

            const keyword = $(event.target).val().toLowerCase();

            filterExistingCustomersTimeout = setTimeout(() => {
                $('#loading').css('visibility', 'hidden');

                App.Http.Customers.search(keyword, 50)
                    .done((response) => {
                        $existingCustomersList.empty();

                        response.forEach((customer) => {
                            $('<div/>', {
                                'data-id': customer.id,
                                'text':
                                    (customer.first_name || '[No First Name]') +
                                    ' ' +
                                    (customer.last_name || '[No Last Name]'),
                            }).appendTo($existingCustomersList);

                            // Verify if this customer is on the old customer list.
                            const result = vars('customers').filter((existingCustomer) => {
                                return Number(existingCustomer.id) === Number(customer.id);
                            });

                            // Add it to the customer list.
                            if (!result.length) {
                                vars('customers').push(customer);
                            }
                        });
                    })
                    .fail(() => {
                        // If there is any error on the request, search by the local client database.
                        $existingCustomersList.empty();

                        vars('customers').forEach((customer) => {
                            if (
                                customer.first_name.toLowerCase().indexOf(keyword) !== -1 ||
                                customer.last_name.toLowerCase().indexOf(keyword) !== -1 ||
                                customer.email.toLowerCase().indexOf(keyword) !== -1 ||
                                customer.phone_number.toLowerCase().indexOf(keyword) !== -1 ||
                                customer.address.toLowerCase().indexOf(keyword) !== -1 ||
                                customer.city.toLowerCase().indexOf(keyword) !== -1 ||
                                customer.zip_code.toLowerCase().indexOf(keyword) !== -1 ||
                                customer.notes.toLowerCase().indexOf(keyword) !== -1
                            ) {
                                $('<div/>', {
                                    'data-id': customer.id,
                                    'text':
                                        (customer.first_name || '[No First Name]') +
                                        ' ' +
                                        (customer.last_name || '[No Last Name]'),
                                }).appendTo($existingCustomersList);
                            }
                        });
                    })
                    .always(() => {
                        $('#loading').css('visibility', '');
                    });
            }, 1000);
        });

        /**
         * Event: Selected Service "Change"
         *
         * When the user clicks on a service, its available providers should become visible. We also need to
         * update the start and end time of the appointment.
         */
        $selectService.on('change', () => {
            const serviceId = $selectService.val();

            const providerId = $selectProvider.val();

            $selectProvider.empty();

            // Automatically update the service duration.
            const service = vars('available_services').find((availableService) => {
                return Number(availableService.id) === Number(serviceId);
            });

            if (service?.color) {
                App.Components.ColorSelection.setColor($appointmentColor, service.color);
            }

            const duration = service ? service.duration : 60;

            const startDateTimeObject = App.Utils.UI.getDateTimePickerValue($startDatetime);
            const endDateTimeObject = new Date(startDateTimeObject.getTime() + duration * 60000);
            App.Utils.UI.setDateTimePickerValue($endDatetime, endDateTimeObject);

            // Update the providers select box.

            vars('available_providers').forEach((provider) => {
                provider.services.forEach((providerServiceId) => {
                    if (
                        vars('role_slug') === App.Layouts.Backend.DB_SLUG_PROVIDER &&
                        Number(provider.id) !== vars('user_id')
                    ) {
                        return; // continue
                    }

                    if (
                        vars('role_slug') === App.Layouts.Backend.DB_SLUG_SECRETARY &&
                        vars('secretary_providers').indexOf(Number(provider.id)) === -1
                    ) {
                        return; // continue
                    }

                    // If the current provider is able to provide the selected service, add him to the list box.
                    if (Number(providerServiceId) === Number(serviceId)) {
                        $selectProvider.append(new Option(provider.first_name + ' ' + provider.last_name, provider.id));
                    }
                });

                if ($selectProvider.find(`option[value="${providerId}"]`).length) {
                    $selectProvider.val(providerId);
                }
            });
        });

        /**
         * Event: Provider "Change"
         */
        $selectProvider.on('change', () => {
            updateTimezone();
        });

        /**
         * Event: Enter New Customer Button "Click"
         */
        $newCustomer.on('click', () => {
            $customerId.val('');
            $firstName.val('');
            $lastName.val('');
            $email.val('');
            $phoneNumber.val('');
            $address.val('');
            $city.val('');
            $zipCode.val('');
            $language.val(vars('default_language'));
            $timezone.val(vars('default_timezone'));
            $customerNotes.val('');
            $customField1.val('');
            $customField2.val('');
            $customField3.val('');
            $customField4.val('');
            $customField5.val('');
        });

        /**
         * Event: Recurring Checkbox "Change"
         */
        $isRecurring.on('change', () => {
            if ($isRecurring.prop('checked')) {
                $recurringOptions.removeClass('d-none');
                initializeRecurringDatePickers();
            } else {
                $recurringOptions.addClass('d-none');
            }
        });


        /**
         * Event: Weekday Checkboxes "Change"
         */
        $weekdayChecks.on('change', updateRecurringPreview);

        /**
         * Event: Recurring Dates "Change"
         */
        $recurringStartDate.on('change', updateRecurringPreview);
        $recurringEndDate.on('change', updateRecurringPreview);
    }

    /**
     * Reset Appointment Dialog
     *
     * This method resets the manage appointment dialog modal to its initial state. After that you can make
     * any modification might be necessary in order to bring the dialog to the desired state.
     */
    function resetModal() {
        // Empty form fields.
        $appointmentsModal.find('input:not([type="checkbox"]), textarea').val('');
        $appointmentsModal.find('input[type="checkbox"]').prop('checked', false);
        $appointmentsModal.find('.modal-message').addClass('.d-none');
        $appointmentsModal.find('.is-invalid').removeClass('is-invalid');

        const defaultStatusValue = $appointmentStatus.find('option:first').val();
        $appointmentStatus.val(defaultStatusValue);

        $language.val(vars('default_language'));
        $timezone.val(vars('default_timezone'));

        // Reset color.
        $appointmentColor.find('.color-selection-option:first').trigger('click');

        // Prepare service and provider select boxes.
        $selectService.val($selectService.eq(0).attr('value'));

        // Fill the providers list box with providers that can serve the appointment's service and then select the
        // user's provider.
        $selectProvider.empty();
        vars('available_providers').forEach((provider) => {
            const serviceId = $selectService.val();

            const canProvideService =
                provider.services.filter((providerServiceId) => {
                    return Number(providerServiceId) === Number(serviceId);
                }).length > 0;

            if (canProvideService) {
                // Add the provider to the list box.
                $selectProvider.append(new Option(provider.first_name + ' ' + provider.last_name, provider.id));
            }
        });

        // Close existing customers-filter frame.
        $existingCustomersList.slideUp('slow');
        $filterExistingCustomers.fadeOut('slow');
        $selectCustomer.find('span').text(lang('select'));

        // Setup start and datetimepickers.
        // Get the selected service duration. It will be needed in order to calculate the appointment end datetime.
        const serviceId = $selectService.val();

        const service = vars('available_services').forEach((service) => Number(service.id) === Number(serviceId));

        const duration = service ? service.duration : 0;

        const startDatetime = new Date();
        const endDatetime = moment().add(duration, 'minutes').toDate();

        App.Utils.UI.initializeDateTimePicker($startDatetime, {
            onClose: () => {
                const serviceId = $selectService.val();

                // Automatically update the #end-datetime DateTimePicker based on service duration.
                const service = vars('available_services').find(
                    (availableService) => Number(availableService.id) === Number(serviceId),
                );

                const startDateTimeObject = App.Utils.UI.getDateTimePickerValue($startDatetime);
                const endDateTimeObject = new Date(startDateTimeObject.getTime() + service.duration * 60000);
                App.Utils.UI.setDateTimePickerValue($endDatetime, endDateTimeObject);
            },
        });

        App.Utils.UI.setDateTimePickerValue($startDatetime, startDatetime);

        App.Utils.UI.initializeDateTimePicker($endDatetime);
        App.Utils.UI.setDateTimePickerValue($endDatetime, endDatetime);
        $appointmentsModal.find('.modal-message').removeClass('alert-danger').text('').addClass('d-none');
    }

    /**
     * Validate the manage appointment dialog data.
     *
     * Validation checks need to run every time the data are going to be saved.
     *
     * @return {Boolean} Returns the validation result.
     */
    function validateAppointmentForm() {
        // Reset previous validation css formatting.
        $appointmentsModal.find('.is-invalid').removeClass('is-invalid');
        $appointmentsModal.find('.modal-message').addClass('d-none');

        try {
            // Check required fields.
            let missingRequiredField = false;

            $appointmentsModal.find('.required').each((index, requiredField) => {
                if ($(requiredField).val() === '' || $(requiredField).val() === null) {
                    $(requiredField).addClass('is-invalid');
                    missingRequiredField = true;
                }
            });

            if (missingRequiredField) {
                throw new Error(lang('fields_are_required'));
            }

            // Check email address.
            if (
                $appointmentsModal.find('#email').val() &&
                !App.Utils.Validation.email($appointmentsModal.find('#email').val())
            ) {
                $appointmentsModal.find('#email').addClass('is-invalid');
                throw new Error(lang('invalid_email'));
            }

            // Check appointment start and end time.
            const startDateTimeObject = App.Utils.UI.getDateTimePickerValue($startDatetime);
            const endDateTimeObject = App.Utils.UI.getDateTimePickerValue($endDatetime);

            if (startDateTimeObject > endDateTimeObject) {
                $startDatetime.addClass('is-invalid');
                $endDatetime.addClass('is-invalid');
                throw new Error(lang('start_date_before_end_error'));
            }

            // Check recurring appointment requirements
            if ($isRecurring.prop('checked')) {
                // Check if at least one weekday is selected
                if ($('.weekday-check:checked').length === 0) {
                    $('.weekday-checkboxes').addClass('is-invalid');
                    throw new Error(lang('select_at_least_one_weekday') || 'Please select at least one day of the week');
                }

                // Check if start and end dates are selected
                const startDateObj = $recurringStartDate[0]._flatpickr;
                const endDateObj = $recurringEndDate[0]._flatpickr;

                if (!startDateObj || !startDateObj.selectedDates[0]) {
                    $recurringStartDate.addClass('is-invalid');
                    throw new Error(lang('select_start_date') || 'Please select a start date');
                }

                if (!endDateObj || !endDateObj.selectedDates[0]) {
                    $recurringEndDate.addClass('is-invalid');
                    throw new Error(lang('select_end_date') || 'Please select an end date');
                }
            }

            return true;
        } catch (error) {
            $appointmentsModal
                .find('.modal-message')
                .addClass('alert-danger')
                .text(error.message)
                .removeClass('d-none');
            return false;
        }
    }

    /**
     * Initialize recurring date pickers.
     * Using DatePicker (not DateTimePicker) since we only need dates,
     * the time comes from the appointment's start/end datetime fields.
     */
    function initializeRecurringDatePickers() {
        if ($recurringStartDate[0]._flatpickr) {
            return; // Already initialized
        }

        App.Utils.UI.initializeDatePicker($recurringStartDate, {
            altInput: true,
            altFormat: 'd/m/Y',
            dateFormat: 'Y-m-d',
        });

        App.Utils.UI.initializeDatePicker($recurringEndDate, {
            altInput: true,
            altFormat: 'd/m/Y',
            dateFormat: 'Y-m-d',
        });
    }

    /**
     * Update recurring preview text.
     */
    function updateRecurringPreview() {
        const recurringData = getRecurringData();
        
        if (!recurringData.start_date || !recurringData.end_date) {
            $recurringPreviewText.text(lang('select_dates_to_see_preview') || 'Select dates to see preview');
            return;
        }

        // Call backend to get preview
        const url = App.Utils.Url.siteUrl('calendar/preview_recurring_appointments');

        const data = {
            ...recurringData,
            csrf_token: vars('csrf_token')
        };

        $.ajax({
            url: url,
            type: 'POST',
            data: data,
            dataType: 'json',
            success: (response) => {
                if (response.success && response.dates) {
                    const count = response.dates.length;
                    // Parse dates in YYYY-MM-DD format (as sent to backend)
                    const start = moment(recurringData.start_date, 'YYYY-MM-DD').format('DD/MM/YYYY');
                    const end = moment(recurringData.end_date, 'YYYY-MM-DD').format('DD/MM/YYYY');

                    let previewText = `${count} ${lang('appointments_will_be_created')} `;
                    previewText += `(${start} - ${end})`;

                    $recurringPreviewText.text(previewText);

                    if (response.conflicts && response.conflicts.length > 0) {
                        const conflictDates = response.conflicts.map(c => moment(c.date).format('DD/MM/YYYY')).join(', ');
                        $recurringPreviewText.append(
                            ` - <strong class="text-danger">${response.conflicts.length} conflito(s): ${conflictDates}</strong>`
                        );
                    }
                } else {
                    $recurringPreviewText.text('Error generating preview');
                }
            },
            error: () => {
                $recurringPreviewText.text('Error generating preview');
            },
        });
    }

    /**
     * Get recurring appointment data from form.
     *
     * @returns {Object} Recurring appointment data.
     */
    function getRecurringData() {
        // Get dates from Flatpickr in YYYY-MM-DD format
        const startDateObj = $recurringStartDate[0]._flatpickr;
        const endDateObj = $recurringEndDate[0]._flatpickr;

        // Always use specific_days type
        const data = {
            recurrence_type: 'specific_days',
            start_date: startDateObj && startDateObj.selectedDates[0] ?
                moment(startDateObj.selectedDates[0]).format('YYYY-MM-DD') : '',
            end_date: endDateObj && endDateObj.selectedDates[0] ?
                moment(endDateObj.selectedDates[0]).format('YYYY-MM-DD') : '',
        };

        // Get selected weekdays
        const weekDays = [];
        const $checkedBoxes = $('.weekday-check:checked');

        console.log('Total weekday checkboxes:', $('.weekday-check').length);
        console.log('Checked weekday checkboxes:', $checkedBoxes.length);

        $checkedBoxes.each(function () {
            const val = $(this).val();
            console.log('Adding weekday:', val);
            weekDays.push(val);
        });

        data.week_days = weekDays.join(',');
        console.log('Final week_days string:', data.week_days);
        console.log('Recurring data:', data); // Debug log

        // Add appointment details from main form
        // The recurring appointments will use the time and duration from the appointment form
        // (Data / hora inicial and Data / hora final) - no need to define time separately
        const startDateTimeObject = App.Utils.UI.getDateTimePickerValue($startDatetime);
        if (startDateTimeObject) {
            data.appointment_time = moment(startDateTimeObject).format('HH:mm:ss');
        }

        const endDateTimeObject = App.Utils.UI.getDateTimePickerValue($endDatetime);
        if (endDateTimeObject && startDateTimeObject) {
            const duration = moment.duration(moment(endDateTimeObject).diff(moment(startDateTimeObject)));
            data.duration = Math.round(duration.asMinutes());
        }

        data.id_users_provider = $selectProvider.val();
        data.id_users_customer = $customerId.val();
        data.id_services = $selectService.val();
        data.location = $appointmentLocation.val();
        data.notes = $appointmentNotes.val();
        data.color = $appointmentColor.val();
        data.status = $appointmentStatus.val();

        return data;
    }

    /**
     * Initialize the module.
     */
    function initialize() {
        addEventListeners();
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {
        resetModal,
        validateAppointmentForm,
    };
})();
