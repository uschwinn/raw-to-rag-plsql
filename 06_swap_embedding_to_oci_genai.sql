-- Optional provider-swap (DB -> remote OCI model) demo: This uses the same chunking call but a remote OCI model.
-- IMPORTANT: embed data and query with the same model, and use a vector column whose dimension matches that model. 

drop table rag_chunks_oci;

create table rag_chunks_oci (
  doc_id   number not null,
  chunk_id number not null,
  chunk_data varchar2(4000) not null,
  embedding vector not null,
  constraint rag_chunks_oci_pk_1 primary key (doc_id, chunk_id)
);

insert into rag_chunks_oci (doc_id, chunk_id, chunk_data, embedding)
select d.doc_id, e.embed_id, e.embed_data, to_vector(e.embed_vector)
from rag_documents d,
     table(
       dbms_vector_chain.utl_to_embeddings(
         dbms_vector_chain.utl_to_chunks(
           dbms_vector_chain.utl_to_text(d.html_blob),
           json('{"by":"words","max":"300","overlap":"20",' ||
                '"split":"recursively","normalize":"all"}')
         ),
         json('{"provider":"ocigenai",' ||
              '"credential_name":"OCI_GENAI_CRED",' ||
              '"url":"https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/20231130/actions/embedText",' ||
              '"model":"cohere.embed-english-v3.0","batch_size":96}')
       )
     ) t,
     json_table(t.column_value, '$[*]'
       columns (
         embed_id number path '$.embed_id',
         embed_data varchar2(4000) path '$.embed_data',
         embed_vector clob path '$.embed_vector'
       )
     ) e;
commit;

-- The only material change from 02_embed_and_index.sql is the JSON provider block.
-- Create the index after confirming the returned dimension in your tenancy/model.

-- Now query it.

set serveroutput on

DECLARE
  l_query_vector VECTOR;
  l_context      CLOB := empty_clob();
  l_prompt       CLOB;
  l_answer       CLOB;
BEGIN
  l_query_vector := dbms_vector_chain.utl_to_embedding(
    :question,
    JSON('{
      "provider": "ocigenai",
      "credential_name": "OCI_GENAI_CRED",
      "url": "https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/20231130/actions/embedText",
      "model": "cohere.embed-english-v3.0"
    }')
  );

  FOR r IN (
    SELECT chunk_id, chunk_data
    FROM rag_chunks_oci
    ORDER BY embedding <=> l_query_vector
    FETCH APPROX FIRST 10 ROWS ONLY
  ) LOOP
    l_context := l_context || chr(10) || '[chunk ' || r.chunk_id || ']' || chr(10)
                 || r.chunk_data || chr(10);
  END LOOP;

  l_prompt := 'Answer only from the supplied context. If the answer is absent, say so. '
           || 'Cite chunk IDs in square brackets.' || chr(10) || chr(10)
           || 'QUESTION: ' || :question || chr(10) || 'CONTEXT:' || l_context;

  l_answer := dbms_vector_chain.utl_to_generate_text(
    l_prompt,
    JSON('{
      "provider": "ocigenai",
      "credential_name": "OCI_GENAI_CRED",
      "url": "https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/20231130/actions/chat",
      "model": "cohere.command-a-03-2025",
      "chatRequest": {
        "maxTokens": 300,
        "temperature": 0
      }
    }')
  );

  dbms_output.put_line(l_answer);
END;
/
