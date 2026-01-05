<?php extend('layouts/account_layout'); ?>

<?php section('content'); ?>

<h2><?= lang('two_factor_verification') ?></h2>

<p>
    <small><?= lang('enter_6_digit_or_recovery_code') ?></small>
    <div class="alert d-none"></div>
</p>

<form id="two-factor-form">
    <div class="mb-3 mt-4">
        <label for="code" class="form-label">
            <?= lang('verification_code') ?>
        </label>
        <input type="text" id="code" class="form-control" placeholder="000000" maxlength="64" required />
    </div>

    <div class="form-check mb-4">
        <input class="form-check-input" type="checkbox" value="1" id="remember" />
        <label class="form-check-label" for="remember">
            <?= lang('remember_this_device_for_30_days') ?>
        </label>
    </div>

    <button type="submit" class="btn btn-primary">
        <i class="fas fa-key me-2"></i>
        <?= lang('verify') ?>
    </button>
</form>

<?php end_section('content'); ?>

<?php section('scripts'); ?>

<script src="<?= asset_url('assets/js/http/two_factor_http_client.js') ?>"></script>
<script src="<?= asset_url('assets/js/pages/two_factor_verify.js') ?>"></script>

<?php end_section('scripts'); ?>



