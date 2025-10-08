<?php defined('BASEPATH') or exit('No direct script access allowed');

/**
 * Domain Events System
 * 
 * Sistema de eventos de domínio para desacoplar funcionalidades
 * e permitir extensões sem modificar o core do EasyAppointments.
 */
class Domain_events
{
    private static $listeners = [];
    private static $events = [];

    /**
     * Registrar um listener para um evento
     */
    public static function listen(string $event, callable $listener): void
    {
        if (!isset(self::$listeners[$event])) {
            self::$listeners[$event] = [];
        }
        self::$listeners[$event][] = $listener;
    }

    /**
     * Disparar um evento
     */
    public static function dispatch($event): void
    {
        $eventName = is_object($event) ? get_class($event) : $event;
        
        // Armazenar evento para processamento posterior
        self::$events[] = $event;
        
        // Processar listeners imediatamente
        if (isset(self::$listeners[$eventName])) {
            foreach (self::$listeners[$eventName] as $listener) {
                try {
                    call_user_func($listener, $event);
                } catch (Exception $e) {
                    log_message('error', 'Domain event listener error: ' . $e->getMessage());
                }
            }
        }
    }

    /**
     * Processar eventos pendentes (para uso pós-commit)
     */
    public static function processPendingEvents(): void
    {
        foreach (self::$events as $event) {
            $eventName = is_object($event) ? get_class($event) : $event;
            
            if (isset(self::$listeners[$eventName])) {
                foreach (self::$listeners[$eventName] as $listener) {
                    try {
                        call_user_func($listener, $event);
                    } catch (Exception $e) {
                        log_message('error', 'Domain event listener error: ' . $e->getMessage());
                    }
                }
            }
        }
        
        // Limpar eventos processados
        self::$events = [];
    }

    /**
     * Limpar todos os listeners
     */
    public static function clear(): void
    {
        self::$listeners = [];
        self::$events = [];
    }
}
