<?php
// Worker to run WhatsApp routines with adaptive backoff.
// Usage: php scripts/whatsapp_worker.php

declare(strict_types=1);
set_time_limit(0);
date_default_timezone_set(getenv('APP_TIMEZONE') ?: (getenv('TZ') ?: 'UTC'));

$dbHost = getenv('WORKER_DB_HOST') ?: getenv('DB_HOST') ?: 'mysql';
$dbUser = getenv('WORKER_DB_USER') ?: getenv('DB_USERNAME') ?: getenv('DB_USER') ?: 'user';
$dbPass = getenv('WORKER_DB_PASS') ?: getenv('DB_PASSWORD') ?: getenv('DB_PASS') ?: 'password';
$dbName = getenv('WORKER_DB_NAME') ?: getenv('DB_DATABASE') ?: getenv('DB_NAME') ?: 'easyappointments';

$intervalWithRoutines = (int) (getenv('WORKER_INTERVAL') ?: 300); // 5min (300 seconds)
$intervalNoRoutines = (int) (getenv('WORKER_NO_ROUTINES_INTERVAL') ?: 600); // 10min

$logFile = __DIR__ . '/../storage/logs/whatsapp_worker.log';
$heartbeatFile = __DIR__ . '/../storage/heartbeat/whatsapp_worker.heartbeat';

// runtime context
$workerPid = getmypid();
$workerRunId = uniqid('wa_worker_', true);
$startTime = time();

function write_worker_log(string $message) {
    global $logFile, $workerPid, $workerRunId;
    $prefix = "[{$workerRunId} pid:{$workerPid}] ";
    $line = '[' . date('c') . '] ' . $prefix . $message . PHP_EOL;
    // ensure directory exists
    $dir = dirname($logFile);
    if (!is_dir($dir)) @mkdir($dir, 0755, true);
    @file_put_contents($logFile, $line, FILE_APPEND | LOCK_EX);
    echo $line;
}

function write_heartbeat(array $metrics = []) {
    global $heartbeatFile, $workerPid, $workerRunId, $startTime;

    $data = [
        'pid' => $workerPid,
        'run_id' => $workerRunId,
        'timestamp' => time(),
        'datetime' => date('c'),
        'uptime_seconds' => time() - $startTime,
        'status' => 'healthy',
        'metrics' => $metrics,
    ];

    $dir = dirname($heartbeatFile);
    if (!is_dir($dir)) @mkdir($dir, 0755, true);

    @file_put_contents($heartbeatFile, json_encode($data, JSON_PRETTY_PRINT), LOCK_EX);

    // Notify systemd watchdog if running under systemd
    if (getenv('WATCHDOG_USEC')) {
        // Send SD_NOTIFY watchdog ping
        $sock = @socket_create(AF_UNIX, SOCK_DGRAM, 0);
        if ($sock && ($addr = getenv('NOTIFY_SOCKET'))) {
            @socket_sendto($sock, "WATCHDOG=1", 10, 0, $addr);
            @socket_close($sock);
        }
    }
}

function check_health(): array {
    global $heartbeatFile;

    if (!file_exists($heartbeatFile)) {
        return ['status' => 'unknown', 'message' => 'No heartbeat file found'];
    }

    $content = @file_get_contents($heartbeatFile);
    if (!$content) {
        return ['status' => 'error', 'message' => 'Cannot read heartbeat file'];
    }

    $data = json_decode($content, true);
    if (!$data) {
        return ['status' => 'error', 'message' => 'Invalid heartbeat data'];
    }

    $age = time() - ($data['timestamp'] ?? 0);

    if ($age > 300) { // 5 minutes
        return ['status' => 'stale', 'message' => "Heartbeat is {$age}s old", 'data' => $data];
    }

    if ($age > 150) { // 2.5 minutes - warning
        return ['status' => 'warning', 'message' => "Heartbeat is {$age}s old", 'data' => $data];
    }

    return ['status' => 'healthy', 'message' => "Last heartbeat {$age}s ago", 'data' => $data];
}

write_worker_log("whatsapp_worker starting (host={$dbHost})");
write_heartbeat(['status' => 'starting']);

$iterationCount = 0;
$totalRoutinesExecuted = 0;

while (true) {
    $iterationCount++;
    $iterationStart = microtime(true);

    $mysqli = @new mysqli($dbHost, $dbUser, $dbPass, $dbName);
    if ($mysqli->connect_errno) {
        write_worker_log("DB connect failed: ({$mysqli->connect_errno}) {$mysqli->connect_error}");
        write_heartbeat([
            'status' => 'error',
            'error' => 'DB connection failed',
            'iterations' => $iterationCount,
        ]);
        sleep(60);
        continue;
    }

    // Verificar se a aplicao j foi instalada (tabela de migraes existe)
    $res = $mysqli->query("SHOW TABLES LIKE 'ea_migrations'");
    if (!$res || $res->num_rows === 0) {
        write_worker_log("App not installed yet (no ea_migrations table)  sleeping 60s");
        if ($res) { $res->free(); }
        $mysqli->close();
        sleep(60);
        continue;
    }

    // Garantir que as tabelas de rotina existem antes de consultar
    $res = $mysqli->query("SHOW TABLES LIKE 'ea_rotinas_whatsapp'");
    if (!$res || $res->num_rows === 0) {
        if ($res) { $res->free(); }
        write_worker_log("No rotinas table yet  sleeping 60s");
        $mysqli->close();
        sleep(60);
        continue;
    }
    $res->free();

    $res = $mysqli->query("SELECT COUNT(*) AS c FROM ea_rotinas_whatsapp WHERE ativa = 1");
    $count = 0;
    if ($res && ($row = $res->fetch_assoc())) {
        $count = (int) $row['c'];
        $res->free();
    }

    if ($count > 0) {
        write_worker_log("Found {$count} active routines  executing run_whatsapp_routines");
        $totalRoutinesExecuted += $count;

        // Execute the console command and capture output
        $cmd = 'php index.php console run_whatsapp_routines 2>&1';
        exec($cmd, $out, $exitCode);
        if (!empty($out)) {
            foreach ($out as $line) write_worker_log(trim($line));
        }
        write_worker_log("run_whatsapp_routines exited with code {$exitCode}");
        $sleep = $intervalWithRoutines;
    } else {
        write_worker_log("No active routines  sleeping {$intervalNoRoutines} seconds");
        $sleep = $intervalNoRoutines;
    }

    $mysqli->close();

    // Write heartbeat with metrics before sleeping
    $iterationDuration = round(microtime(true) - $iterationStart, 2);
    write_heartbeat([
        'status' => 'running',
        'active_routines' => $count,
        'iteration' => $iterationCount,
        'total_routines_executed' => $totalRoutinesExecuted,
        'iteration_duration_sec' => $iterationDuration,
        'next_check_in_sec' => $sleep,
        'memory_usage_mb' => round(memory_get_usage(true) / 1024 / 1024, 2),
    ]);

    sleep($sleep);
}


