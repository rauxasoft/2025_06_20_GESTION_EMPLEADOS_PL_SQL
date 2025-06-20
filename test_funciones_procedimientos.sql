BEGIN
  IF employment_module.is_email_duplicated('tminet7@noaa.gov') THEN
    DBMS_OUTPUT.PUT_LINE('Duplicado');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Disponible');
  END IF;
END;
/

-- para ver la salida debo activar la consola ver>DBMS Output/  y con el botón + verde activar para la conexión.

-- Prueba de inserción...

SET SERVEROUTPUT ON;

DECLARE
  v_id NUMBER := NULL;
BEGIN
  employment_module.create_or_edit(
    p_employee_id     => v_id,
    p_name            => 'Ana Prueba',
    p_email           => 'ana@demo.com',
    p_phone_number    => '612345678',
    p_date_of_joining => TO_DATE('2024-06-20', 'YYYY-MM-DD')
  );

  DBMS_OUTPUT.PUT_LINE('Empleado insertado con ID: ' || v_id);
END;
/

BEGIN
  employment_module.remove(10000);  -- Asegúrate de que el ID existe
  DBMS_OUTPUT.PUT_LINE('Empleado eliminado correctamente.');
END;
/