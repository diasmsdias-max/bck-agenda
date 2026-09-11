BEGIN;

-- EP05 padroniza o nome funcional FINISHED. A migration original usava COMPLETED.
ALTER TABLE appointment DROP CONSTRAINT IF EXISTS appointment_status_check;
UPDATE appointment SET status = 'FINISHED' WHERE status = 'COMPLETED';
ALTER TABLE appointment ADD CONSTRAINT appointment_status_check
    CHECK (status IN ('SCHEDULED','CONFIRMED','WAITING','IN_SERVICE','FINISHED','CANCELLED','NO_SHOW','RESCHEDULED'));

-- O agendamento original permanece no histórico e aponta para o novo atendimento.
ALTER TABLE appointment
    ADD COLUMN rescheduled_to_appointment_id uuid NULL REFERENCES appointment(id),
    ADD COLUMN rescheduled_from_appointment_id uuid NULL REFERENCES appointment(id);

CREATE UNIQUE INDEX ux_appointment_rescheduled_from
    ON appointment(rescheduled_from_appointment_id)
    WHERE rescheduled_from_appointment_id IS NOT NULL;

CREATE INDEX ix_appointment_rescheduled_to
    ON appointment(rescheduled_to_appointment_id)
    WHERE rescheduled_to_appointment_id IS NOT NULL;

COMMIT;
