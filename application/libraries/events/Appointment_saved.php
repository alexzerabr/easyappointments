<?php defined('BASEPATH') or exit('No direct script access allowed');

/**
 * Appointment Saved Event
 * 
 * Evento disparado quando um agendamento é salvo (criado ou atualizado)
 */
class Appointment_saved
{
    public $appointment_id;
    public $action_type; // 'create', 'update', 'statusChanged'
    public $old_appointment;
    public $new_appointment;

    /**
     * Make constructor optional so CI loader can instantiate the class without arguments.
     * When dispatching events, callers can still create with the full signature.
     */
    public function __construct(?int $appointment_id = null, ?string $action_type = null, ?array $old_appointment = null, ?array $new_appointment = null)
    {
        $this->appointment_id = $appointment_id;
        $this->action_type = $action_type;
        $this->old_appointment = $old_appointment;
        $this->new_appointment = $new_appointment;
    }
}
