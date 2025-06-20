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
    
    PROCEDURE get_employees(
        p_page_number       IN NUMBER,
        p_page_size         IN NUMBER,
        p_order_by          IN VARCHAR2,
        p_result_cursor     OUT SYS_REFCURSOR,
        p_total_records     OUT NUMBER,
        p_total_pages       OUT NUMBER,
        p_page_count        OUT NUMBER
    ) IS
        v_sql               VARCHAR2(1000);
        v_offset            NUMBER;
        v_order             VARCHAR2(50);
    
    BEGIN
    
        -- Validar y establecer orden por defecto
        IF p_order_by IS NULL OR UPPER(p_order_by) NOT IN ('NAME', 'EMAIL', 'PHONE_NUMBER', 'DATE_OF_JOINING') THEN
            v_order := 'employee_id';
        ELSE
            v_order := LOWER(p_order_by);
        END IF;

        -- Calcular offset
        v_offset := (p_page_number - 1) * p_page_size;

        -- Contar total de registros
        SELECT COUNT(*) INTO p_total_records FROM employees;

        -- Calcular total de páginas
        p_total_pages := CEIL(p_total_records / p_page_size);

        -- Construir SQL dinámico con paginación
        v_sql := '
            SELECT *
              FROM employees
          ORDER BY ' || v_order || '
            OFFSET :1 ROWS FETCH NEXT :2 ROWS ONLY';

        -- Abrir cursor con los resultados paginados
        OPEN p_result_cursor FOR v_sql USING v_offset, p_page_size;

        -- Calcular cuántos registros tiene esta página (por si es la última y está incompleta)
        IF v_offset + p_page_size > p_total_records THEN
            p_page_count := GREATEST(p_total_records - v_offset, 0);
        ELSE
            p_page_count := p_page_size;
        END IF;
    END get_employees;
    
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
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (11, 'Brook Matiewe', 'bmatiewea@google.com.hk', '173-521-5861', TO_DATE('2013-05-09', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (12, 'Julina Paulot', 'jpaulotb@howstuffworks.com', '688-933-0662', TO_DATE('2013-05-01', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (13, 'Neilla Culleford', 'ncullefordc@engadget.com', '205-163-8122', TO_DATE('2023-09-07', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (14, 'Bernetta Else', 'belsed@com.com', '295-484-3940', TO_DATE('2017-01-31', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (15, 'Hildegaard Giorgeschi', 'hgiorgeschie@flavors.me', '193-833-7141', TO_DATE('2024-09-21', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (16, 'Herold De Castri', 'hdef@ftc.gov', '504-271-8249', TO_DATE('2019-04-30', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (17, 'Brittney Gammie', 'bgammieg@google.ca', '592-330-4653', TO_DATE('2022-01-13', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (18, 'Huntley Lippingwell', 'hlippingwellh@usnews.com', '957-523-2284', TO_DATE('2024-10-17', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (19, 'Francisco Lavender', 'flavenderi@google.ca', '623-321-8398', TO_DATE('2024-01-27', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (20, 'Clementius Domerc', 'cdomercj@ow.ly', '494-204-9172', TO_DATE('2017-02-04', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (21, 'Lorelei Breddy', 'lbreddyk@netvibes.com', '814-445-4185', TO_DATE('2018-03-05', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (22, 'Catha Pieche', 'cpiechel@yellowbook.com', '746-550-9518', TO_DATE('2010-04-09', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (23, 'Garrek Forestel', 'gforestelm@disqus.com', '847-609-3638', TO_DATE('2022-02-22', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (24, 'Candida Olivas', 'colivasn@dailymail.co.uk', '919-811-6570', TO_DATE('2019-04-23', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (25, 'Antonetta Demaine', 'ademaineo@blogtalkradio.com', '892-115-1745', TO_DATE('2015-12-03', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (26, 'Sharity Ransom', 'sransomp@wikia.com', '962-425-9514', TO_DATE('2021-05-07', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (27, 'Jacquenetta Reditt', 'jredittq@google.com.hk', '549-110-4946', TO_DATE('2023-11-04', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (28, 'Dulsea Brewett', 'dbrewettr@nasa.gov', '392-773-9850', TO_DATE('2023-06-06', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (29, 'Eleanore Grgic', 'egrgics@bluehost.com', '121-675-8599', TO_DATE('2021-09-09', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (30, 'Stefania Burchnall', 'sburchnallt@rediff.com', '372-338-6402', TO_DATE('2019-10-08', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (31, 'Beniamino Okenfold', 'bokenfoldu@imgur.com', '389-433-3798', TO_DATE('2020-07-31', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (32, 'Leontyne Drinkeld', 'ldrinkeldv@mapquest.com', '959-843-5751', TO_DATE('2023-11-02', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (33, 'Gerrie Rosellini', 'groselliniw@ftc.gov', '224-887-2297', TO_DATE('2015-04-17', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (34, 'Barnabe Mineghelli', 'bmineghellix@pinterest.com', '619-157-2829', TO_DATE('2019-10-12', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (35, 'Gaston Salaman', 'gsalamany@walmart.com', '774-388-8069', TO_DATE('2024-12-12', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (36, 'Johan Riddles', 'jriddlesz@lycos.com', '596-897-9994', TO_DATE('2010-12-10', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (37, 'Abbye Spooner', 'aspooner10@amazon.de', '875-186-3268', TO_DATE('2019-12-08', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (38, 'Jean Jerger', 'jjerger11@parallels.com', '981-222-9338', TO_DATE('2019-10-06', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (39, 'Hillie Warden', 'hwarden12@xing.com', '723-326-3258', TO_DATE('2020-11-14', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (40, 'Deeanne Tabary', 'dtabary13@goodreads.com', '509-735-4856', TO_DATE('2019-05-23', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (41, 'Ludwig Lambal', 'llambal14@pcworld.com', '400-280-0107', TO_DATE('2018-08-29', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (42, 'Willie Tonbridge', 'wtonbridge15@slashdot.org', '246-457-4822', TO_DATE('2018-11-11', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (43, 'Carmelina Stearn', 'cstearn16@privacy.gov.au', '303-833-8541', TO_DATE('2024-01-04', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (44, 'Eugen Dawidowicz', 'edawidowicz17@shinystat.com', '536-305-2925', TO_DATE('2014-11-21', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (45, 'Berkly Roycroft', 'broycroft18@etsy.com', '276-105-5074', TO_DATE('2018-06-11', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (46, 'Brittney Szapiro', 'bszapiro19@linkedin.com', '418-738-4054', TO_DATE('2012-02-15', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (47, 'Dukey Balleine', 'dballeine1a@1688.com', '558-576-3127', TO_DATE('2014-03-31', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (48, 'Tamera Copley', 'tcopley1b@imageshack.us', '680-471-8500', TO_DATE('2023-09-26', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (49, 'Maribel Shoebotham', 'mshoebotham1c@chicagotribune.com', '965-807-9389', TO_DATE('2016-02-07', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (50, 'Kiley Dyte', 'kdyte1d@tumblr.com', '175-857-1195', TO_DATE('2024-03-09', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (51, 'Peta Coupland', 'pcoupland1e@canalblog.com', '377-889-4562', TO_DATE('2019-10-13', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (52, 'Zorina Timeby', 'ztimeby1f@forbes.com', '495-764-7122', TO_DATE('2017-10-16', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (53, 'Ethe Bynold', 'ebynold1g@google.com.br', '541-138-5308', TO_DATE('2012-05-28', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (54, 'Rosabella Samson', 'rsamson1h@cam.ac.uk', '190-593-8132', TO_DATE('2012-09-23', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (55, 'Miranda Peddersen', 'mpeddersen1i@eventbrite.com', '639-305-9853', TO_DATE('2018-08-04', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (56, 'Karly Rives', 'krives1j@cpanel.net', '811-393-2019', TO_DATE('2013-08-13', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (57, 'Griffie Lowings', 'glowings1k@mapy.cz', '849-744-3134', TO_DATE('2016-09-06', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (58, 'Mariellen Farrent', 'mfarrent1l@sciencedaily.com', '577-590-4930', TO_DATE('2012-09-14', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (59, 'Bethany Wasielewski', 'bwasielewski1m@xinhuanet.com', '414-483-7169', TO_DATE('2021-08-14', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (60, 'Sibley Bernardoni', 'sbernardoni1n@mysql.com', '532-644-0365', TO_DATE('2020-12-09', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (61, 'Barry Blackader', 'bblackader1o@phpbb.com', '885-176-7065', TO_DATE('2013-09-26', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (62, 'Lindon Davydzenko', 'ldavydzenko1p@usa.gov', '173-376-8038', TO_DATE('2019-06-02', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (63, 'Ursa Fedoronko', 'ufedoronko1q@spiegel.de', '655-404-2742', TO_DATE('2010-11-14', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (64, 'Gusta Oloman', 'goloman1r@unesco.org', '261-142-0960', TO_DATE('2021-08-09', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (65, 'Tyrone Rings', 'trings1s@liveinternet.ru', '153-725-2464', TO_DATE('2012-04-11', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (66, 'Netty Morrid', 'nmorrid1t@posterous.com', '844-758-8182', TO_DATE('2022-11-01', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (67, 'Lenka Mazzei', 'lmazzei1u@dmoz.org', '451-619-4707', TO_DATE('2010-01-22', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (68, 'Glynnis Konerding', 'gkonerding1v@dmoz.org', '733-200-9032', TO_DATE('2020-04-23', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (69, 'Nell Khristoforov', 'nkhristoforov1w@hatena.ne.jp', '186-534-1071', TO_DATE('2019-02-20', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (70, 'Gabriel Henriques', 'ghenriques1x@parallels.com', '382-680-2492', TO_DATE('2021-04-29', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (71, 'Bernice Wilkin', 'bwilkin1y@jiathis.com', '723-865-9738', TO_DATE('2017-07-12', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (72, 'See Liell', 'sliell1z@gravatar.com', '140-869-4128', TO_DATE('2015-10-02', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (73, 'Raimundo Babb', 'rbabb20@webmd.com', '354-306-0656', TO_DATE('2011-10-01', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (74, 'Boonie Kirkby', 'bkirkby21@nifty.com', '575-164-5369', TO_DATE('2014-01-06', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (75, 'Jeremias Paschek', 'jpaschek22@narod.ru', '954-848-7278', TO_DATE('2025-02-08', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (76, 'Hewie Bickers', 'hbickers23@senate.gov', '419-212-5348', TO_DATE('2022-05-13', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (77, 'Celestina Gornal', 'cgornal24@japanpost.jp', '465-962-8204', TO_DATE('2023-06-06', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (78, 'Jethro Lassetter', 'jlassetter25@newsvine.com', '398-749-5904', TO_DATE('2020-10-10', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (79, 'Jerrilyn Kaesmans', 'jkaesmans26@soup.io', '811-766-3647', TO_DATE('2023-07-13', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (80, 'Sabina Cultcheth', 'scultcheth27@dailymotion.com', '162-590-0581', TO_DATE('2010-09-01', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (81, 'Roscoe Dureden', 'rdureden28@mac.com', '813-878-4392', TO_DATE('2015-10-25', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (82, 'Petra Elvins', 'pelvins29@java.com', '161-951-3469', TO_DATE('2010-01-23', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (83, 'Cory Meeland', 'cmeeland2a@studiopress.com', '381-833-4272', TO_DATE('2018-06-10', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (84, 'Frederich Scemp', 'fscemp2b@wikimedia.org', '765-489-2390', TO_DATE('2016-01-27', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (85, 'Mychal Biasini', 'mbiasini2c@live.com', '305-709-1705', TO_DATE('2015-12-11', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (86, 'Eula Karpmann', 'ekarpmann2d@joomla.org', '412-553-1409', TO_DATE('2016-07-03', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (87, 'Donavon Urey', 'durey2e@bigcartel.com', '194-929-1230', TO_DATE('2014-11-18', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (88, 'Cobb Pallis', 'cpallis2f@woothemes.com', '500-797-6467', TO_DATE('2020-06-13', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (89, 'Birgitta Stutter', 'bstutter2g@reuters.com', '396-915-9588', TO_DATE('2021-05-25', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (90, 'Chrissie Eckh', 'ceckh2h@marketwatch.com', '346-583-0786', TO_DATE('2013-11-14', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (91, 'Patin MacMakin', 'pmacmakin2i@mozilla.org', '521-469-9869', TO_DATE('2017-12-02', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (92, 'Tonya Melchior', 'tmelchior2j@xinhuanet.com', '556-119-2747', TO_DATE('2019-05-30', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (93, 'Omar McCarty', 'omccarty2k@pcworld.com', '441-229-2312', TO_DATE('2011-08-30', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (94, 'Hallie Stritton', 'hstritton2l@princeton.edu', '485-474-5694', TO_DATE('2021-02-10', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (95, 'Paton Dunkerton', 'pdunkerton2m@hhs.gov', '207-624-7641', TO_DATE('2022-01-03', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (96, 'Robinette Westrip', 'rwestrip2n@accuweather.com', '754-462-7288', TO_DATE('2018-08-27', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (97, 'Vladimir Jaffrey', 'vjaffrey2o@cdbaby.com', '882-276-1105', TO_DATE('2013-12-10', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (98, 'Josey Daleman', 'jdaleman2p@archive.org', '918-124-6707', TO_DATE('2014-05-07', 'YYYY-MM-DD'));
insert into EMPLOYEES (employee_id, name, email, phone_number, date_of_joining) values (99, 'Karie Blenkinsopp', 'kblenkinsopp2q@sakura.ne.jp', '411-901-9464', TO_DATE('2012-03-29', 'YYYY-MM-DD'));

