<?php defined('BASEPATH') or exit('No direct script access allowed');

/*
| -------------------------------------------------------------------------
| Hooks
| -------------------------------------------------------------------------
| This file lets you define "hooks" to extend CI without hacking the core
| files.  Please see the user guide for info:
|
|	http://codeigniter.com/user_guide/general/hooks.html
|
*/

/*
| -------------------------------------------------------------------------
| WhatsApp Integration Hooks
| -------------------------------------------------------------------------
| Register WhatsApp hooks for appointment notifications
*/
$hook['post_controller_constructor'] = [
    'class' => 'Whatsapp_hooks',
    'function' => 'register',
    'filename' => 'whatsapp_hooks.php',
    'filepath' => 'hooks',
];

/* End of file hooks.php */
/* Location: ./application/config/hooks.php */
