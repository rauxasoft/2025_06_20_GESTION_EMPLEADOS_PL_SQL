SET SERVEROUTPUT ON;

DECLARE
  v_cursor         SYS_REFCURSOR;
  v_id             NUMBER;
  v_name           VARCHAR2(100);
  v_email          VARCHAR2(150);
  v_phone          VARCHAR2(20);
  v_date_joining   DATE;

  v_total_records  NUMBER;
  v_total_pages    NUMBER;
  v_page_count     NUMBER;
BEGIN
  employment_module.get_employees(
    p_page_number    => 1,
    p_page_size      => 10,
    p_order_by       => 'name',
    p_result_cursor  => v_cursor,
    p_total_records  => v_total_records,
    p_total_pages    => v_total_pages,
    p_page_count     => v_page_count
  );

  DBMS_OUTPUT.PUT_LINE('Total registros: ' || v_total_records);
  DBMS_OUTPUT.PUT_LINE('Total páginas:   ' || v_total_pages);
  DBMS_OUTPUT.PUT_LINE('Elementos esta página: ' || v_page_count);
  DBMS_OUTPUT.PUT_LINE('--- Página 1 ---');

  LOOP
    FETCH v_cursor INTO v_id, v_name, v_email, v_phone, v_date_joining;
    EXIT WHEN v_cursor%NOTFOUND;

    DBMS_OUTPUT.PUT_LINE(
      v_id || ' - ' || v_name || ' - ' || v_email || ' - ' ||
      v_phone || ' - ' || TO_CHAR(v_date_joining, 'YYYY-MM-DD')
    );
  END LOOP;

  CLOSE v_cursor;
END;
/