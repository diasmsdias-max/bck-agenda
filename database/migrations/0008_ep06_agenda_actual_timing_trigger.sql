BEGIN;

CREATE OR REPLACE FUNCTION bck_capture_appointment_actual_timing()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        IF NEW.status = 'WAITING' AND NEW.arrived_at IS NULL THEN
            NEW.arrived_at := now();
        END IF;

        IF NEW.status = 'IN_SERVICE' AND NEW.service_started_at IS NULL THEN
            NEW.service_started_at := now();
        END IF;

        IF NEW.status = 'FINISHED' AND NEW.service_finished_at IS NULL THEN
            NEW.service_finished_at := now();
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_appointment_actual_timing ON appointment;
CREATE TRIGGER trg_appointment_actual_timing
BEFORE UPDATE OF status ON appointment
FOR EACH ROW
EXECUTE FUNCTION bck_capture_appointment_actual_timing();

COMMIT;
