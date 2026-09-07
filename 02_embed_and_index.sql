-- Demonstrate DBMS_VECTOR_CHAIN.UTL_TO_TEXT, DBMS_VECTOR_CHAIN.UTL_TO_CHUNK, and DBMS_VECTOR_CHAIN.UTL_TO_EMBEDDINGS
-- Create chunks table with related chunks embeddings  

set timing on
set serveroutput on

begin
  execute immediate 'drop table rag_chunks purge';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/

create table rag_chunks as
select d.doc_id,
       e.embed_id as chunk_id,
       e.embed_data as chunk_data,
       to_vector(e.embed_vector) as embedding
from rag_documents d,
     table(
       dbms_vector_chain.utl_to_embeddings(
         dbms_vector_chain.utl_to_chunks(
           dbms_vector_chain.utl_to_text(d.html_blob),
           json('{
             "by":"words",
             "max":"200",
             "overlap":"20",
             "split":"recursively",
             "normalize":"all"
           }')
         ),
         json('{
           "provider":"database",
           "model":"MINILM_L12_V2"
         }')
       )
     ) t,
     json_table(
       t.column_value,
       '$[*]'
       columns (
         embed_id     number         path '$.embed_id',
         embed_data   varchar2(4000) path '$.embed_data',
         embed_vector clob           path '$.embed_vector'
       )
     ) e
where length(trim(e.embed_data)) > 50;

alter table rag_chunks add constraint rag_chunks_pk primary key (doc_id, chunk_id);

select count(*)
from rag_chunks;


-- (optional) vector index creation
-- small table here so an HNSW index is overkill, but may be worth demonstrating

create vector index doc_chunks_hnsw_idx on rag_chunks (embedding)
organization inmemory neighbor graph
distance cosine
with target accuracy 95;


