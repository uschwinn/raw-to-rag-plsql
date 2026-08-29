-- UTL_TO_GENERATE_TEXT for RAG
-- Retrieve the top 10 matching chunks, merge them into a prompt, generate a grounded natural-language answer. 
-- please provide your choice for provider, credential, third party provider endpoint and model
-- here we use OCI Generative AI, cohere and OCI_GENAI_CRED


-- Try some questions such as: 
-- Who attends the tea party?
-- Why is the White Rabbit in a hurry?
-- What did Alice think about a book without pictures or conversations?
-- What happend when Alice drinks from the litte magic bottle?
-- Which animal was sitting on a mushroom?
-- Why does Alice fall down the rabbit hole?
-- What is the task of the Queen of Hearts?

-- please make sure that the credential exists.

set serverout on
declare
  l_query_vector vector;
  l_context      clob := empty_clob();
  l_prompt       clob;
  l_answer       clob;
begin
  l_query_vector := dbms_vector_chain.utl_to_embedding(
    :question, json('{"provider":"database","model":"MINILM_L12_V2"}')
  );

  for r in (
    select chunk_id, chunk_data
    from rag_chunks
    order by embedding <=> l_query_vector
    fetch approx first 5 rows only
  ) loop
    l_context := l_context || chr(10) || '[chunk ' || r.chunk_id || ']' || chr(10)
                 || r.chunk_data || chr(10);
  end loop;

  l_prompt := 'Answer only from the supplied context. If the answer is absent, say so. '
           || 'Cite chunk IDs in square brackets.' || chr(10) || chr(10)
           || 'QUESTION: ' || :question || chr(10) || 'CONTEXT:' || l_context;

  l_answer := dbms_vector_chain.utl_to_generate_text(
    l_prompt,
    json('{"provider":"ocigenai",' ||
         '"credential_name":"OCI_GENAI_CRED",' ||
         '"url":"https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/20231130/actions/chat",' ||
         '"model":"cohere.command-a-03-2025",' ||
         '"chatRequest":{"maxTokens":300,"temperature":0}}')
  );

  dbms_output.put_line(l_answer);
end;
/
