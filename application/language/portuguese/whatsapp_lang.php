<?php defined('BASEPATH') or exit('No direct script access allowed');

// Fallback to 'portuguese-br' translations if 'portuguese' locale is requested.
$br_path = __DIR__ . '/portuguese-br/whatsapp_lang.php';
if (file_exists($br_path)) {
    require $br_path;
} else {
    // Minimal fallback to avoid fatal errors: define empty translations
    $lang = [];
}



