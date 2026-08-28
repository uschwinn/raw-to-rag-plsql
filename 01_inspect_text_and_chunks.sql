-- Demonstrate UTL_TEXT, UTL_TEXT_CHUNK

set long 30000
set longchunksize 30000
set pagesize 200
set linesize 220

-- Convert from HTML BLOB -> text CLOB. Show only the first 3,000 characters.
select dbms_lob.substr(
         regexp_replace(
           dbms_vector_chain.utl_to_text(html_blob),
           '[[:space:]]+',
           ' '
         ),
         3000,
         10000
       ) as extracted_text
from rag_documents;

-- From text -> JSON chunks. Change MAX and OVERLAP and compare 1
-- Keep MAX modest and change OVERLAP if necessary: e.g. MAX 400 and OVERLAP 0, MAX 200 and OVERLAP 20
-- Oracle requires nonzero overlap to be at least 5% of MAX,

select j.chunk_id,
       j.chunk_offset,
       j.chunk_length,
       substr(j.chunk_data, 1, 500) as chunk_preview
from rag_documents d,
     table(
       dbms_vector_chain.utl_to_chunks(
         dbms_vector_chain.utl_to_text(d.html_blob),
         json('{"by":"words","max":"200","overlap":"20",' ||
              '"split":"recursively","normalize":"all"}')
       )
     ) c,
     json_table(c.column_value, '$'
       columns (
         chunk_id     number         path '$.chunk_id',
         chunk_offset number         path '$.chunk_offset',
         chunk_length number         path '$.chunk_length',
         chunk_data   varchar2(4000) path '$.chunk_data'
       )
     ) j
order by j.chunk_id
fetch first 8 rows only;

-- Fast comparison after changing MAX, OVERLAP and SPLIT above.

select count(*) as chunk_count,
       min(j.chunk_length) as smallest_chars,
       round(avg(j.chunk_length)) as avg_chars,
       max(j.chunk_length) as largest_chars
from rag_documents d,
     table(dbms_vector_chain.utl_to_chunks(
       dbms_vector_chain.utl_to_text(d.html_blob),
       json('{"by":"words","max":"200","overlap":"20",' ||
            '"split":"recursively","normalize":"all"}')
     )) c,
     json_table(c.column_value, '$'
       columns (chunk_length number path '$.chunk_length')) j;
