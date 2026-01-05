<?php defined('BASEPATH') or exit('No direct script access allowed');

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
 * API Documentation controller.
 *
 * Serves the OpenAPI/Swagger documentation for the REST API.
 *
 * @package Controllers
 */
class Docs_api_v1 extends EA_Controller
{
    /**
     * Docs_api_v1 constructor.
     */
    public function __construct()
    {
        parent::__construct();
    }

    /**
     * Display Swagger UI.
     *
     * Renders the Swagger UI interface for API documentation.
     */
    public function index(): void
    {
        $this->load->view('api/swagger_ui');
    }

    /**
     * Get OpenAPI specification.
     *
     * Returns the OpenAPI 3.0 specification as JSON.
     */
    public function spec(): void
    {
        $spec_path = FCPATH . 'docs/api-specs/openapi.yaml';

        if (!file_exists($spec_path)) {
            http_response_code(404);
            header('Content-Type: application/json');
            echo json_encode([
                'code' => 404,
                'message' => 'OpenAPI specification file not found'
            ]);
            return;
        }

        $yaml_content = file_get_contents($spec_path);

        // Check if yaml_parse is available (requires YAML extension)
        if (function_exists('yaml_parse')) {
            $spec = yaml_parse($yaml_content);

            if ($spec === false) {
                http_response_code(500);
                header('Content-Type: application/json');
                echo json_encode([
                    'code' => 500,
                    'message' => 'Failed to parse OpenAPI specification'
                ]);
                return;
            }

            header('Content-Type: application/json');
            echo json_encode($spec, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        } else {
            // Fallback: Return YAML directly
            header('Content-Type: application/x-yaml');
            echo $yaml_content;
        }
    }

    /**
     * Get OpenAPI specification as YAML.
     *
     * Returns the raw OpenAPI 3.0 YAML specification.
     */
    public function spec_yaml(): void
    {
        $spec_path = FCPATH . 'docs/api-specs/openapi.yaml';

        if (!file_exists($spec_path)) {
            http_response_code(404);
            header('Content-Type: application/json');
            echo json_encode([
                'code' => 404,
                'message' => 'OpenAPI specification file not found'
            ]);
            return;
        }

        header('Content-Type: application/x-yaml');
        header('Content-Disposition: inline; filename="openapi.yaml"');
        readfile($spec_path);
    }
}

/* End of file Docs_api_v1.php */
/* Location: ./application/controllers/api/v1/Docs_api_v1.php */
