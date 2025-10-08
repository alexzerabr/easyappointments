<?php defined('BASEPATH') or exit('No direct script access allowed');

/*
| -------------------------------------------------------------------------
| URI ROUTING
| -------------------------------------------------------------------------
| This file lets you re-map URI requests to specific controller functions.
|
| Typically there is a one-to-one relationship between a URL string
| and its corresponding controller class/method. The segments in a
| URL normally follow this pattern:
|
|	example.com/class/method/id/
|
| In some instances, however, you may want to remap this relationship
| so that a different class/function is called than the one
| corresponding to the URL.
|
| Please see the user guide for complete details:
|
|	https://codeigniter.com/userguide3/general/routing.html
|
| -------------------------------------------------------------------------
| RESERVED ROUTES
| -------------------------------------------------------------------------
|
| There are three reserved routes:
|
|	$route['default_controller'] = 'welcome';
|
| This route indicates which controller class should be loaded if the
| URI contains no data. In the above example, the "welcome" class
| would be loaded.
|
|	$route['404_override'] = 'errors/page_missing';
|
| This route will tell the Router which controller/method to use if those
| provided in the URL cannot be matched to a valid route.
|
|	$route['translate_uri_dashes'] = FALSE;
|
| This is not exactly a route, but allows you to automatically route
| controller and method names that contain dashes. '-' isn't a valid
| class or method name character, so it requires translation.
| When you set this option to TRUE, it will replace ALL dashes with
| underscores in the controller and method URI segments.
|
| Examples:	my-controller/index	-> my_controller/index
|		my-controller/my-method	-> my_controller/my_method
*/

require_once __DIR__ . '/../helpers/routes_helper.php';

$route['default_controller'] = 'booking';

$route['404_override'] = '';

$route['translate_uri_dashes'] = FALSE;

/*
| -------------------------------------------------------------------------
| FRAME OPTIONS HEADERS
| -------------------------------------------------------------------------
| Set the appropriate headers so that iframe control and permissions are 
| properly configured.
|
| Enable this if you want to disable use of Easy!Appointments within an 
| iframe.
|
| Options:
|
|   - DENY 
|   - SAMEORIGIN 
|
*/

// header('X-Frame-Options: SAMEORIGIN');

/*
| -------------------------------------------------------------------------
| CORS HEADERS
| -------------------------------------------------------------------------
| Set the appropriate headers so that CORS requirements are met and any 
| incoming preflight options request succeeds. 
|
*/

header('Access-Control-Allow-Origin: ' . ($_SERVER['HTTP_ORIGIN'] ?? '*')); // NOTICE: Change this header to restrict CORS access.

header('Access-Control-Allow-Credentials: "true"');

if (isset($_SERVER['HTTP_ACCESS_CONTROL_REQUEST_METHOD']))
{
    // May also be using PUT, PATCH, HEAD etc
    header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD');
}

if (isset($_SERVER['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']))
{
    header('Access-Control-Allow-Headers: ' . $_SERVER['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']);
}

if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'OPTIONS')
{
    exit(0);
}

/*
| -------------------------------------------------------------------------
| REST API ROUTING
| -------------------------------------------------------------------------
| Define the API resource routes using the routing helper function. By 
| default, each resource will have by default the following actions: 
| 
|   - index [GET]
|
|   - show/:id [GET]
|
|   - store [POST]
|
|   - update [PUT]
|
|   - destroy [DELETE]
|
| Some resources like the availabilities and the settings do not follow this 
| pattern and are explicitly defined. 
|
*/

route_api_resource($route, 'appointments', 'api/v1/');

route_api_resource($route, 'admins', 'api/v1/');

route_api_resource($route, 'service_categories', 'api/v1/');

route_api_resource($route, 'customers', 'api/v1/');

route_api_resource($route, 'providers', 'api/v1/');

route_api_resource($route, 'secretaries', 'api/v1/');

route_api_resource($route, 'services', 'api/v1/');

route_api_resource($route, 'unavailabilities', 'api/v1/');

route_api_resource($route, 'webhooks', 'api/v1/');

route_api_resource($route, 'blocked_periods', 'api/v1/');

$route['api/v1/settings']['get'] = 'api/v1/settings_api_v1/index';

$route['api/v1/settings/(:any)']['get'] = 'api/v1/settings_api_v1/show/$1';

$route['api/v1/settings/(:any)']['put'] = 'api/v1/settings_api_v1/update/$1';

$route['api/v1/availabilities']['get'] = 'api/v1/availabilities_api_v1/get';

/*
| -------------------------------------------------------------------------
| WHATSAPP INTEGRATION ROUTING
| -------------------------------------------------------------------------
| Routes for WhatsApp integration functionality
|
*/

// WhatsApp Integration Settings
$route['whatsapp_integration'] = 'whatsapp_integration/index';
$route['whatsapp_integration/save']['post'] = 'whatsapp_integration/save';
$route['whatsapp_integration/update_token']['post'] = 'whatsapp_integration/update_token';
$route['whatsapp_integration/generate_token']['post'] = 'whatsapp_integration/generate_token';
$route['whatsapp_integration/start_session']['post'] = 'whatsapp_integration/start_session';
$route['whatsapp_integration/get_status'] = 'whatsapp_integration/get_status';
$route['whatsapp_integration/close_session'] = 'whatsapp_integration/close_session';
$route['whatsapp_integration/logout_session'] = 'whatsapp_integration/logout_session';
$route['whatsapp_integration/test_connectivity'] = 'whatsapp_integration/test_connectivity';
$route['whatsapp_integration/get_message_logs']['get'] = 'whatsapp_integration/get_message_logs';
$route['whatsapp_integration/send_message']['post'] = 'whatsapp_integration/send_message';
$route['whatsapp_integration/can_send_message']['get'] = 'whatsapp_integration/can_send_message';
$route['whatsapp_integration/get_statistics']['get'] = 'whatsapp_integration/get_statistics';
$route['whatsapp_integration/send_test_message']['post'] = 'whatsapp_integration/send_test_message';
$route['whatsapp_integration/get_message_logs']['get'] = 'whatsapp_integration/get_message_logs';
$route['whatsapp_integration/get_message_stats']['get'] = 'whatsapp_integration/get_message_stats';

// WhatsApp Templates Management
$route['whatsapp_templates'] = 'whatsapp_templates/index';
$route['whatsapp_templates/get_templates']['get'] = 'whatsapp_templates/get_templates';
$route['whatsapp_templates/get_template/(:num)']['get'] = 'whatsapp_templates/get_template/$1';
$route['whatsapp_templates/save_template']['post'] = 'whatsapp_templates/save_template';
$route['whatsapp_templates/delete_template/(:num)']['delete'] = 'whatsapp_templates/delete_template/$1';
$route['whatsapp_templates/get_preview']['post'] = 'whatsapp_templates/get_preview';
$route['whatsapp_templates/get_statuses']['get'] = 'whatsapp_templates/get_statuses';
$route['whatsapp_templates/get_variables']['get'] = 'whatsapp_templates/get_variables';
$route['whatsapp_templates/get_placeholders']['get'] = 'whatsapp_templates/get_placeholders'; // Legacy compatibility
$route['whatsapp_templates/validate_variables']['post'] = 'whatsapp_templates/validate_variables';
// $route['whatsapp_templates/create_default_templates']['post'] = 'whatsapp_templates/create_default_templates'; // removed: no auto defaults
$route['whatsapp_templates/toggle_template/(:num)']['put'] = 'whatsapp_templates/toggle_template/$1';
$route['whatsapp_templates/duplicate_template/(:num)']['post'] = 'whatsapp_templates/duplicate_template/$1';
$route['whatsapp_templates/bulk_update']['post'] = 'whatsapp_templates/bulk_update';
$route['whatsapp_templates/export_templates']['get'] = 'whatsapp_templates/export_templates';
$route['whatsapp_templates/import_templates']['post'] = 'whatsapp_templates/import_templates';

/*
| -------------------------------------------------------------------------
| TWO FACTOR AUTH ROUTING
| -------------------------------------------------------------------------
*/
$route['two_factor'] = 'two_factor/verify';
$route['two_factor/verify'] = 'two_factor/verify';
$route['two_factor/validate']['post'] = 'two_factor/validate';
$route['two_factor/remember']['post'] = 'two_factor/remember';
$route['two_factor/is_device_remembered']['get'] = 'two_factor/is_device_remembered';
$route['two_factor/setup_init']['post'] = 'two_factor/setup_init';
$route['two_factor/setup_enable']['post'] = 'two_factor/setup_enable';
$route['two_factor/setup_disable']['post'] = 'two_factor/setup_disable';
$route['two_factor/regenerate_recovery_codes']['post'] = 'two_factor/regenerate_recovery_codes';
$route['two_factor/devices']['get'] = 'two_factor/devices';
$route['two_factor/revoke_device']['post'] = 'two_factor/revoke_device';

/*
| -------------------------------------------------------------------------
| CUSTOM ROUTING
| -------------------------------------------------------------------------
| You can add custom routes to the following section to define URL patterns
| that are later mapped to the available controllers in the filesystem. 
|
*/

/* End of file routes.php */
/* Location: ./application/config/routes.php */
