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

begin
  execute immediate 'drop table rag_chunk_embeddings purge';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/

begin
  execute immediate 'drop table rag_chunk_text purge';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/


-- 1. Persist chunk text from UTL_TO_CHUNKS itself in a temporary staging table.

create table rag_chunk_text as
select d.doc_id,
       j.chunk_id,
       j.chunk_data
from rag_documents d,
     table(
       dbms_vector_chain.utl_to_chunks(
         dbms_vector_chain.utl_to_text(d.html_blob),
         json('{"by":"words","max":"200","overlap":"20",' ||
              '"split":"recursively","normalize":"all"}')
       )
     ) c,
     json_table(
       c.column_value,
       '$'
       columns (
         chunk_id   number         path '$.chunk_id',
         chunk_data varchar2(4000) path '$.chunk_data'
       )
     ) j
where length(trim(j.chunk_data)) > 50;

-- 2. Batch-create the in-database ONNX embeddings.
-- The output's embed_id is the source chunk_id; embed_data is intentionally ignored.

create table rag_chunk_embeddings as
select d.doc_id,
       e.embed_id as chunk_id,
       to_vector(e.embed_vector) as embedding
from rag_documents d,
     table(
       dbms_vector_chain.utl_to_embeddings(
         dbms_vector_chain.utl_to_chunks(
           dbms_vector_chain.utl_to_text(d.html_blob),
           json('{"by":"words","max":"200","overlap":"20",' ||
                '"split":"recursively","normalize":"all"}')
         ),
         json('{"provider":"database","model":"MINILM_L12_V2"}')
       )
     ) t,
     json_table(
       t.column_value,
       '$[*]'
       columns (
         embed_id     number path '$.embed_id',
         embed_vector clob   path '$.embed_vector'
       )
     ) e;

alter table rag_chunk_embeddings
  add constraint rag_chunk_embeddings_pk primary key (doc_id, chunk_id);

-- 3. Join text to its embedding. CTAS derives the precise VECTOR type from EMBEDDING.

create table rag_chunks as
select t.doc_id,
       t.chunk_id,
       t.chunk_data,
       e.embedding
from rag_chunk_text t
join rag_chunk_embeddings e
  on e.doc_id = t.doc_id
 and e.chunk_id = t.chunk_id;

alter table rag_chunks add constraint rag_chunks_pk primary key (doc_id, chunk_id);

drop table rag_chunk_text purge;
drop table rag_chunk_embeddings purge;
commit;

select count(*)
from rag_chunks;


-- (optional) vector index creation
-- small table here so an HNSW index is overkill, but may be worth demonstrating

create vector index doc_chunks_hnsw_idx on rag_chunks (embedding)
organization inmemory neighbor graph
distance cosine
with target accuracy 95;


