-- =============================================
-- Limpieza previa: drop con control de errores
-- =============================================

BEGIN
  -- Drop table employees
  BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE employees';
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN -- ORA-00942: table or view does not exist
      RAISE;
    END IF;
  END;

  -- Drop sequence employee_seq
  BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE employee_seq';
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -2289 THEN -- ORA-02289: sequence does not exist
      RAISE;
    END IF;
  END;

  -- Drop package employment_module
  BEGIN
    EXECUTE IMMEDIATE 'DROP PACKAGE employment_module';
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -4043 THEN -- ORA-04043: object does not exist
      RAISE;
    END IF;
  END;
END;
/

-- =============================================
-- Creación de objetos
-- =============================================

CREATE TABLE employees (
  employee_id     NUMBER PRIMARY KEY,
  name            VARCHAR2(100) NOT NULL,
  email           VARCHAR2(150) NOT NULL UNIQUE,
  phone_number    VARCHAR2(20) NOT NULL,
  date_of_joining DATE NOT NULL
);
/

CREATE SEQUENCE employee_seq
  START WITH 2000
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;
  
/

-- Ejecutamos primero la cabecera

CREATE OR REPLACE PACKAGE employment_module AS

    FUNCTION is_email_duplicated(
        p_email             IN VARCHAR2,
        p_employee_id       IN NUMBER DEFAULT NULL
    ) RETURN BOOLEAN;
  
    PROCEDURE create_or_edit(
        p_employee_id       IN OUT NUMBER,
        p_name              IN VARCHAR2,
        p_email             IN VARCHAR2,
        p_phone_number      IN VARCHAR2,
        p_date_of_joining   IN DATE
    );
    
    PROCEDURE remove(
        p_employee_id IN NUMBER
    );
    
    PROCEDURE get_employees(
        p_page_number       IN NUMBER,
        p_page_size         IN NUMBER,
        p_order_by          IN VARCHAR2,
        p_result_cursor     OUT SYS_REFCURSOR,
        p_total_records     OUT NUMBER,
        p_total_pages       OUT NUMBER,
        p_page_count        OUT NUMBER
    );
  
END employment_module;
/

-- Ejecutamos el cuerpo

CREATE OR REPLACE PACKAGE BODY employment_module AS

    -- Función de validación de email duplicado
    
    FUNCTION is_email_duplicated(
        p_email             IN VARCHAR2,
        p_employee_id       IN NUMBER DEFAULT NULL
    ) RETURN BOOLEAN IS v_count NUMBER := 0;
    
    BEGIN
        SELECT COUNT(*) INTO v_count
          FROM employees
         WHERE LOWER(email) = LOWER(p_email)
           AND (p_employee_id IS NULL OR employee_id != p_employee_id);
        
        RETURN v_count > 0;
        
    END is_email_duplicated;
    
    -- Procedimiento para crear o editar empleados
    
    PROCEDURE create_or_edit(
        p_employee_id       IN OUT NUMBER,
        p_name              IN VARCHAR2,
        p_email             IN VARCHAR2,
        p_phone_number      IN VARCHAR2,
        p_date_of_joining   IN DATE) IS
    
    BEGIN
    
        -- Validar email duplicado
        IF is_email_duplicated(p_email, p_employee_id) THEN
            RAISE_APPLICATION_ERROR(-20001, 'El email ya está registrado.');
        END IF;

        -- INSERT si el ID es NULL
        IF p_employee_id IS NULL THEN
            
            SELECT employee_seq.NEXTVAL INTO p_employee_id FROM dual;

            INSERT INTO employees (employee_id, name, email, phone_number, date_of_joining) 
                 VALUES (p_employee_id, p_name, p_email, p_phone_number, p_date_of_joining);

        ELSE
            -- UPDATE si el ID existe
            UPDATE employees
               SET             name = p_name,
                              email = p_email,
                       phone_number = p_phone_number,
                    date_of_joining = p_date_of_joining
            WHERE employee_id = p_employee_id;

            -- Si no se actualizó nada, lanzar error
            IF SQL%ROWCOUNT = 0 THEN 
                RAISE_APPLICATION_ERROR(-20002, 'No se encontró ningún empleado con ese ID.');
            END IF;
        END IF;
    END create_or_edit;
  
    -- Procedimiento para eliminar empleados
  
    PROCEDURE remove(
        p_employee_id       IN NUMBER
    ) IS
    
    BEGIN
        DELETE 
          FROM employees
         WHERE employee_id = p_employee_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'No se encontró ningún empleado con ese ID.');
        END IF;
    END remove;
    
    
    
END employment_module;
/

-- =============================================
-- Datos de ejemplo
-- =============================================

insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (1, 'Layne Bugdell', 'lbugdell0@bloglovin.com', '130-775-3397', TO_DATE('2021-08-31', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (2, 'Job Tripcony', 'jtripcony1@slate.com', '744-333-8354', TO_DATE('2020-04-12', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (3, 'Lani Easson', 'leasson2@java.com', '928-161-1769', TO_DATE('2020-10-03', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (4, 'Ranique Terren', 'rterren3@livejournal.com', '676-109-1781', TO_DATE('2011-11-27', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (5, 'Shoshana Housecraft', 'shousecraft4@comsenz.com', '106-736-0793', TO_DATE('2025-02-20', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (6, 'Teddy Setterfield', 'tsetterfield5@usgs.gov', '592-995-9965', TO_DATE('2022-12-03', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (7, 'Rolland Poytheras', 'rpoytheras6@hugedomains.com', '807-470-1482', TO_DATE('2018-12-01', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (8, 'Tami Minet', 'tminet7@noaa.gov', '474-294-4488', TO_DATE('2016-05-03', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (9, 'Romeo Bicheno', 'rbicheno8@examiner.com', '968-881-2801', TO_DATE('2010-06-06', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (10, 'Lelia Barstock', 'lbarstock9@reddit.com', '441-114-0082', TO_DATE('2013-05-22', 'YYYY-MM-DD'));

