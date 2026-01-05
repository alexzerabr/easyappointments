<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Easy!Appointments API Documentation</title>
    <link rel="icon" type="image/png" href="<?= base_url('assets/img/favicon.ico') ?>">
    <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui.css">
    <style>
        html {
            box-sizing: border-box;
            overflow-y: scroll;
        }

        *,
        *:before,
        *:after {
            box-sizing: inherit;
        }

        body {
            margin: 0;
            background: #fafafa;
        }

        .swagger-ui .topbar {
            background-color: #2c3e50;
            padding: 10px 0;
        }

        .swagger-ui .topbar .download-url-wrapper .select-label {
            color: #fff;
        }

        .swagger-ui .topbar .download-url-wrapper input[type=text] {
            border-color: #3498db;
        }

        .swagger-ui .info .title {
            color: #2c3e50;
        }

        .swagger-ui .info .title small.version-stamp {
            background-color: #3498db;
        }

        .swagger-ui .btn.authorize {
            border-color: #27ae60;
            color: #27ae60;
        }

        .swagger-ui .btn.authorize svg {
            fill: #27ae60;
        }

        .swagger-ui .opblock.opblock-get .opblock-summary-method {
            background: #3498db;
        }

        .swagger-ui .opblock.opblock-post .opblock-summary-method {
            background: #27ae60;
        }

        .swagger-ui .opblock.opblock-put .opblock-summary-method {
            background: #f39c12;
        }

        .swagger-ui .opblock.opblock-delete .opblock-summary-method {
            background: #e74c3c;
        }

        .swagger-ui .opblock.opblock-patch .opblock-summary-method {
            background: #9b59b6;
        }

        /* Custom header */
        .custom-header {
            background: linear-gradient(135deg, #2c3e50 0%, #3498db 100%);
            color: white;
            padding: 20px;
            text-align: center;
        }

        .custom-header h1 {
            margin: 0 0 10px 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            font-weight: 600;
        }

        .custom-header p {
            margin: 0;
            opacity: 0.9;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        }

        .custom-header a {
            color: #fff;
            text-decoration: underline;
        }

        /* Hide default topbar */
        .swagger-ui .topbar {
            display: none;
        }

        /* Loading state */
        #swagger-ui-loading {
            text-align: center;
            padding: 50px;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            color: #666;
        }

        #swagger-ui-loading .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #3498db;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 20px;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="custom-header">
        <h1>Easy!Appointments API Documentation</h1>
        <p>RESTful API v1 - OpenAPI 3.0 Specification | <a href="<?= site_url() ?>">Back to App</a></p>
    </div>

    <div id="swagger-ui">
        <div id="swagger-ui-loading">
            <div class="spinner"></div>
            <p>Loading API documentation...</p>
        </div>
    </div>

    <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-bundle.js"></script>
    <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-standalone-preset.js"></script>
    <script>
        window.onload = function() {
            const ui = SwaggerUIBundle({
                url: "<?= site_url('api/v1/docs/spec.yaml') ?>",
                dom_id: '#swagger-ui',
                deepLinking: true,
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIStandalonePreset
                ],
                plugins: [
                    SwaggerUIBundle.plugins.DownloadUrl
                ],
                layout: "StandaloneLayout",
                validatorUrl: null,
                supportedSubmitMethods: ['get', 'post', 'put', 'delete', 'patch'],
                defaultModelsExpandDepth: 1,
                defaultModelExpandDepth: 1,
                docExpansion: 'list',
                filter: true,
                showExtensions: true,
                showCommonExtensions: true,
                persistAuthorization: true,
                displayRequestDuration: true,
                tryItOutEnabled: false
            });

            window.ui = ui;
        };
    </script>
</body>
</html>
