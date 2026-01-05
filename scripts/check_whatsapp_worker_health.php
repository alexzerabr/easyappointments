#!/usr/bin/env php
<?php
/**
 * WhatsApp Worker Health Check Script
 *
 * Usage:
 *   php scripts/check_whatsapp_worker_health.php [--json] [--nagios]
 *
 * Exit codes:
 *   0 - Healthy
 *   1 - Warning
 *   2 - Critical/Error
 *   3 - Unknown
 *
 * Options:
 *   --json    Output as JSON
 *   --nagios  Nagios-compatible output
 */

declare(strict_types=1);

$heartbeatFile = __DIR__ . '/../storage/heartbeat/whatsapp_worker.heartbeat';
$outputFormat = 'text'; // text, json, nagios

// Parse command line options
if (in_array('--json', $argv ?? [])) {
    $outputFormat = 'json';
}
if (in_array('--nagios', $argv ?? [])) {
    $outputFormat = 'nagios';
}

function check_health(string $heartbeatFile): array {
    if (!file_exists($heartbeatFile)) {
        return [
            'status' => 'unknown',
            'exit_code' => 3,
            'message' => 'No heartbeat file found - worker may not be running',
            'data' => null,
        ];
    }

    $content = @file_get_contents($heartbeatFile);
    if (!$content) {
        return [
            'status' => 'error',
            'exit_code' => 2,
            'message' => 'Cannot read heartbeat file',
            'data' => null,
        ];
    }

    $data = json_decode($content, true);
    if (!$data) {
        return [
            'status' => 'error',
            'exit_code' => 2,
            'message' => 'Invalid heartbeat data (corrupted JSON)',
            'data' => null,
        ];
    }

    $age = time() - ($data['timestamp'] ?? 0);
    $uptime = $data['uptime_seconds'] ?? 0;

    // Critical: heartbeat older than 5 minutes
    if ($age > 300) {
        return [
            'status' => 'critical',
            'exit_code' => 2,
            'message' => "Worker appears DEAD - last heartbeat {$age}s ago",
            'data' => $data,
            'age_seconds' => $age,
        ];
    }

    // Warning: heartbeat older than 2.5 minutes
    if ($age > 150) {
        return [
            'status' => 'warning',
            'exit_code' => 1,
            'message' => "Worker may be STUCK - last heartbeat {$age}s ago",
            'data' => $data,
            'age_seconds' => $age,
        ];
    }

    // Check metrics for anomalies
    $warnings = [];
    $metrics = $data['metrics'] ?? [];

    // Memory warning (>200MB)
    if (isset($metrics['memory_usage_mb']) && $metrics['memory_usage_mb'] > 200) {
        $warnings[] = sprintf('High memory usage: %.2f MB', $metrics['memory_usage_mb']);
    }

    // Iteration duration warning (>30s)
    if (isset($metrics['iteration_duration_sec']) && $metrics['iteration_duration_sec'] > 30) {
        $warnings[] = sprintf('Slow iteration: %.2f seconds', $metrics['iteration_duration_sec']);
    }

    if (!empty($warnings)) {
        return [
            'status' => 'warning',
            'exit_code' => 1,
            'message' => 'Worker healthy but with warnings: ' . implode(', ', $warnings),
            'data' => $data,
            'age_seconds' => $age,
            'warnings' => $warnings,
        ];
    }

    return [
        'status' => 'healthy',
        'exit_code' => 0,
        'message' => sprintf(
            'Worker is HEALTHY (uptime: %s, last heartbeat: %ds ago)',
            format_uptime($uptime),
            $age
        ),
        'data' => $data,
        'age_seconds' => $age,
    ];
}

function format_uptime(int $seconds): string {
    $days = floor($seconds / 86400);
    $hours = floor(($seconds % 86400) / 3600);
    $mins = floor(($seconds % 3600) / 60);

    $parts = [];
    if ($days > 0) $parts[] = "{$days}d";
    if ($hours > 0) $parts[] = "{$hours}h";
    if ($mins > 0 || empty($parts)) $parts[] = "{$mins}m";

    return implode(' ', $parts);
}

function output_text(array $result): void {
    echo "WhatsApp Worker Health Check\n";
    echo str_repeat('=', 50) . "\n\n";

    $statusEmoji = [
        'healthy' => '',
        'warning' => '',
        'critical' => '',
        'error' => '',
        'unknown' => '?',
    ];

    echo "{$statusEmoji[$result['status']]} Status: " . strtoupper($result['status']) . "\n";
    echo "Message: {$result['message']}\n\n";

    if ($result['data']) {
        echo "Worker Details:\n";
        echo "  PID: {$result['data']['pid']}\n";
        echo "  Run ID: {$result['data']['run_id']}\n";
        echo "  Uptime: " . format_uptime($result['data']['uptime_seconds']) . "\n";
        echo "  Last Heartbeat: {$result['data']['datetime']}\n";
        echo "  Age: {$result['age_seconds']}s\n";

        if (!empty($result['data']['metrics'])) {
            echo "\nMetrics:\n";
            foreach ($result['data']['metrics'] as $key => $value) {
                $formatted = is_numeric($value) ? $value : json_encode($value);
                echo "  " . ucwords(str_replace('_', ' ', $key)) . ": {$formatted}\n";
            }
        }

        if (!empty($result['warnings'])) {
            echo "\nWarnings:\n";
            foreach ($result['warnings'] as $warning) {
                echo "   {$warning}\n";
            }
        }
    }
}

function output_json(array $result): void {
    echo json_encode($result, JSON_PRETTY_PRINT) . "\n";
}

function output_nagios(array $result): void {
    $nagiosStatus = [
        0 => 'OK',
        1 => 'WARNING',
        2 => 'CRITICAL',
        3 => 'UNKNOWN',
    ];

    $status = $nagiosStatus[$result['exit_code']] ?? 'UNKNOWN';
    $perfData = '';

    if ($result['data']) {
        $metrics = $result['data']['metrics'] ?? [];
        $perfParts = [];

        if (isset($result['age_seconds'])) {
            $perfParts[] = "age={$result['age_seconds']}s;150;300";
        }
        if (isset($result['data']['uptime_seconds'])) {
            $perfParts[] = "uptime={$result['data']['uptime_seconds']}s";
        }
        if (isset($metrics['memory_usage_mb'])) {
            $perfParts[] = "memory={$metrics['memory_usage_mb']}MB;200;250";
        }
        if (isset($metrics['iteration_duration_sec'])) {
            $perfParts[] = "iteration_time={$metrics['iteration_duration_sec']}s;30;60";
        }
        if (isset($metrics['active_routines'])) {
            $perfParts[] = "active_routines={$metrics['active_routines']}";
        }

        if (!empty($perfParts)) {
            $perfData = ' | ' . implode(' ', $perfParts);
        }
    }

    echo "WHATSAPP_WORKER {$status} - {$result['message']}{$perfData}\n";
}

// Main execution
$result = check_health($heartbeatFile);

switch ($outputFormat) {
    case 'json':
        output_json($result);
        break;
    case 'nagios':
        output_nagios($result);
        break;
    default:
        output_text($result);
}

exit($result['exit_code']);
