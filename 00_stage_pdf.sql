-- Run in your Autonomous AI Database schema.
-- Paste a READ-ONLY, time-limited Object Storage PAR for one PDF here.

set serveroutput on
set long 20000
set pagesize 100

begin
  execute immediate 'drop table rag_documents purge';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/


-- create app user and replace username and password

create user &username identified by &password;

grant db_developer_role, connect to &username;
grant all on dbms_cloud to &username;
 
alter user &username quota unlimited on users;

grant create mining model to &username;

-- optional REST enable user
BEGIN
  ORDS_ADMIN.ENABLE_SCHEMA(
    p_enabled => TRUE,
    p_schema => '&username',
    p_url_mapping_type => 'BASE_PATH',
    p_url_mapping_pattern => '&username',
    p_auto_rest_auth=> TRUE
  );
  -- ENABLE DATA SHARING

  C##ADP$SERVICE.DBMS_SHARE.ENABLE_SCHEMA(
    SCHEMA_NAME => '&username',
    ENABLED => TRUE
  );
  commit;
END;
/



-- connect as app user and create the table for the document

create table rag_documents (
  doc_id       number generated always as identity primary key,
  title        varchar2(500) not null,
  source_url   varchar2(4000) not null,
  html_blob    blob not null,
  loaded_at    timestamp default systimestamp not null
);


insert into rag_documents (title, source_url, html_blob)
select 'Alice’s Adventures in Wonderland', 'OCI_CRED',
       dbms_cloud.get_object(
         credential_name => null,
         object_uri      => 'https://objectstorage.us-sanjose-1.oraclecloud.com/n/oradbclouducm/b/bucketus/o/Alice%E2%80%99s%20Adventures%20in%20Wonderland%20_%20Project%20Gutenberg.html')
from dual;

commit;


select doc_id, title,
       round(dbms_lob.getlength(html_blob) / 1024 / 1024, 2) as html_mb,
       loaded_at
from rag_documents;
