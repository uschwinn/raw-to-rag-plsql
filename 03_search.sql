-- Demonstrate similarity search with DBMS_VECTOR_CHAIN.UTL_TO_EMBEDDING
-- If your environment does not allow FETCH APPROX, use FETCH FIRST for an exact scan.
-- In the workshop we use MINILM_L12_V2, change if required. 

set linesize 220
set pagesize 100
set long 10000

var question varchar2(1000)
exec :question := 'Who attends the tea party?'

-- in SQL Actions or other SQL client tool
-- Same in-database model embeds the question. FETCH APPROX makes the HNSW path explicit.
select chunk_id,
       round(vector_distance(
         embedding,
         dbms_vector_chain.utl_to_embedding(
           :questions,
           json('{"provider":"database","model":"MINILM_L12_V2"}')
         ), cosine), 4) as cosine_distance,
       substr(chunk_data, 1, 750) as retrieved_chunk
from rag_chunks
order by embedding <=> dbms_vector_chain.utl_to_embedding(
  :questions, json('{"provider":"database","model":"MINILM_L12_V2"}')
)
fetch approx first 5 rows only;


