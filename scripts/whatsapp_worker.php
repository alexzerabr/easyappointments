<?php
// Worker to run WhatsApp routines with adaptive backoff.
// Usage: php scripts/whatsapp_worker.php

declare(strict_types=1);
set_time_limit(0);
date_default_timezone_set(getenv('APP_TIMEZONE') ?: (getenv('TZ') ?: 'UTC'));

$dbHost = getenv('WORKER_DB_HOST') ?: getenv('DB_HOST') ?: 'mysql';
$dbUser = getenv('WORKER_DB_USER') ?: getenv('DB_USER') ?: 'user';
$dbPass = getenv('WORKER_DB_PASS') ?: getenv('DB_PASS') ?: 'password';
$dbName = getenv('WORKER_DB_NAME') ?: getenv('DB_NAME') ?: 'easyappointments';

$intervalWithRoutines = (int) (getenv('WORKER_INTERVAL') ?: 300); // 5min (300 seconds)
$intervalNoRoutines = (int) (getenv('WORKER_NO_ROUTINES_INTERVAL') ?: 600); // 10min

$logFile = __DIR__ . '/../storage/logs/whatsapp_worker.log';

// runtime context
$workerPid = getmypid();
$workerRunId = uniqid('wa_worker_', true);

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

write_worker_log("whatsapp_worker starting (host={$dbHost})");

while (true) {
    $mysqli = @new mysqli($dbHost, $dbUser, $dbPass, $dbName);
    if ($mysqli->connect_errno) {
        write_worker_log("DB connect failed: ({$mysqli->connect_errno}) {$mysqli->connect_error}");
        sleep(60);
        continue;
    }

    // Verificar se a aplicação já foi instalada (tabela de migrações existe)
    $res = $mysqli->query("SHOW TABLES LIKE 'ea_migrations'");
    if (!$res || $res->num_rows === 0) {
        write_worker_log("App not installed yet (no ea_migrations table) — sleeping 60s");
        if ($res) { $res->free(); }
        $mysqli->close();
        sleep(60);
        continue;
    }

    // Garantir que as tabelas de rotina existem antes de consultar
    $res = $mysqli->query("SHOW TABLES LIKE 'ea_rotinas_whatsapp'");
    if (!$res || $res->num_rows === 0) {
        if ($res) { $res->free(); }
        write_worker_log("No rotinas table yet — sleeping 60s");
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
        write_worker_log("Found {$count} active routines — executing run_whatsapp_routines");
        // Execute the console command and capture output
        $cmd = 'php index.php console run_whatsapp_routines 2>&1';
        exec($cmd, $out, $exitCode);
        if (!empty($out)) {
            foreach ($out as $line) write_worker_log(trim($line));
        }
        write_worker_log("run_whatsapp_routines exited with code {$exitCode}");
        $sleep = $intervalWithRoutines;
    } else {
        write_worker_log("No active routines — sleeping {$intervalNoRoutines} seconds");
        $sleep = $intervalNoRoutines;
    }

    $mysqli->close();
    sleep($sleep);
}


