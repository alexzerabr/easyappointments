# WhatsApp Token Runbook

This runbook explains how to rotate, revoke and respond to incidents involving the WPPConnect token used by Easy!Appointments.

## Key locations
- Token stored encrypted in DB table `whatsapp_integration_settings` column `token_enc`.
- Audit logs: `ea_whatsapp_token_reveal_logs` (reveal/copy/rotate events).
- Encryption key: environment variable `WA_TOKEN_ENC_KEY` (must be 32+ bytes). Use your secret manager.

## Rotate token (recommended flow)
1. On the Settings page, click `Rotacionar token` and confirm. The app will call `POST /whatsapp_integration/rotate_token`.
2. The system will call WPPConnect to get a new token, persist it (encrypted) and update the service config.
3. Verify integration by testing connectivity and sending a test message.
4. Record the rotation event in your change log and notify stakeholders.

## Emergency revocation
1. Immediately rotate token following the procedure above.
2. If WPPConnect supports revocation, perform it via their admin/API.
3. Inspect `ea_whatsapp_message_logs` for any suspicious sends.
4. Review `ea_whatsapp_token_reveal_logs` for unexpected reveals/copies.

## Access control
- Only users with `PRIV_SYSTEM_SETTINGS` and `edit` permissions may reveal or rotate tokens.
- Reveal actions are rate-limited and audited.

## Secrets management
- Store `WA_TOKEN_ENC_KEY` in a secure secret manager (Vault, AWS Secrets Manager, Kubernetes secrets, etc.).
- Never commit keys to git.

## CI / Pre-commit
- Use the provided GitHub Action `gitleaks` to scan for potential secrets in PRs/pushes.


