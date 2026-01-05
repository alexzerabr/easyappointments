<?php
/**
 * Recurring series modal component for editing recurring appointments.
 */
?>

<div id="recurring-series-modal" class="modal fade" data-bs-backdrop="static">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title"><?= lang('edit_recurring_series') ?></h5>
                <button class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <p><?= lang('recurring_series_edit_prompt') ?></p>
                <div class="d-grid gap-2">
                    <button class="btn btn-outline-primary" id="edit-this-appointment" data-action="this_one">
                        <i class="fas fa-calendar-day"></i>
                        <?= lang('only_this_appointment') ?>
                    </button>
                    <button class="btn btn-outline-primary" id="edit-future-appointments" data-action="future">
                        <i class="fas fa-calendar-week"></i>
                        <?= lang('this_and_future_appointments') ?>
                    </button>
                    <button class="btn btn-primary" id="edit-all-appointments" data-action="all">
                        <i class="fas fa-calendar"></i>
                        <?= lang('all_appointments_in_series') ?>
                    </button>
                </div>
            </div>
        </div>
    </div>
</div>

<div id="recurring-delete-modal" class="modal fade" data-bs-backdrop="static">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title"><?= lang('delete_recurring_series') ?></h5>
                <button class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <p><?= lang('recurring_series_delete_prompt') ?></p>
                <div class="d-grid gap-2">
                    <button class="btn btn-outline-danger" id="delete-this-appointment" data-action="this_one">
                        <i class="fas fa-calendar-day"></i>
                        <?= lang('only_this_appointment') ?>
                    </button>
                    <button class="btn btn-outline-danger" id="delete-future-appointments" data-action="future">
                        <i class="fas fa-calendar-week"></i>
                        <?= lang('this_and_future_appointments') ?>
                    </button>
                    <button class="btn btn-danger" id="delete-all-appointments" data-action="all">
                        <i class="fas fa-calendar"></i>
                        <?= lang('all_appointments_in_series') ?>
                    </button>
                </div>
            </div>
        </div>
    </div>
</div>

<?php section('scripts'); ?>

<script src="<?= asset_url('assets/js/components/recurring_series_modal.js') ?>"></script>

<?php end_section('scripts'); ?>


