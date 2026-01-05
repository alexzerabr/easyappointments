<?php defined('BASEPATH') or exit('No direct script access allowed');

/* ----------------------------------------------------------------------------
 * Easy!Appointments - Online Appointment Scheduler
 *
 * Lightweight TOTP library to avoid external dependencies for development.
 * Implements RFC 6238 using HMAC-SHA1 by default.
 * ---------------------------------------------------------------------------- */

class Totp
{
    /**
     * Verify a TOTP code for a given Base32 secret.
     *
     * @param string $base32_secret Base32 encoded secret
     * @param string $code User provided code
     * @param int $window Adjacent time windows to allow (for clock skew)
     * @param int $period Time step in seconds
     * @param int $digits Number of digits
     *
     * @return bool
     */
    public function verify(string $base32_secret, string $code, int $window = 1, int $period = 30, int $digits = 6): bool
    {
        $secret = $this->base32Decode($base32_secret);

        if ($secret === '') {
            return false;
        }

        $code = preg_replace('/\D/', '', $code);

        if ($code === '' || strlen($code) < 6 || strlen($code) > 8) {
            return false;
        }

        $timeSlice = floor(time() / $period);

        for ($i = -$window; $i <= $window; $i++) {
            $calc = $this->calculateCode($secret, $timeSlice + $i, $digits);
            if (hash_equals($calc, $code)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Calculate a TOTP code for a given secret and time window.
     */
    private function calculateCode(string $secret, int $timeSlice, int $digits = 6): string
    {
        $time = pack('N*', 0) . pack('N*', $timeSlice);
        $hash = hash_hmac('sha1', $time, $secret, true);
        $offset = ord(substr($hash, -1)) & 0x0F;
        $truncatedHash = substr($hash, $offset, 4);
        $value = unpack('N', $truncatedHash)[1] & 0x7FFFFFFF;
        $modulo = 10 ** $digits;
        return str_pad((string) ($value % $modulo), $digits, '0', STR_PAD_LEFT);
    }

    /**
     * Decode a Base32 encoded string.
     */
    private function base32Decode(string $b32): string
    {
        $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
        $b32 = strtoupper(preg_replace('/[^A-Z2-7=]/', '', $b32));

        if ($b32 === '') {
            return '';
        }

        $bits = '';
        $result = '';

        for ($i = 0, $len = strlen($b32); $i < $len; $i++) {
            $val = strpos($alphabet, $b32[$i]);
            if ($val === false) {
                continue;
            }
            $bits .= str_pad(decbin($val), 5, '0', STR_PAD_LEFT);
        }

        for ($i = 0, $len = strlen($bits); $i + 8 <= $len; $i += 8) {
            $result .= chr(bindec(substr($bits, $i, 8)));
        }

        return $result;
    }
}



