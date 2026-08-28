# Raw Data to RAG — Autonomous AI Database 26ai demo

This is a small, live-demo-first RAG build.  It starts with a real HTML document stored in OCI Object Storage and makes each transformation visible:

`Object Storage HTML → BLOB → text → chunks → embeddings → vector search → grounded answer`

Run the scripts in this order using Database Actions SQL, SQL Developer, or SQLcl:

1. `00a_load_onnx_from_object_storage.sql` — one-time model setup
2. `00_stage_pdf.sql`
3. `01_inspect_text_and_chunks.sql`
4. `02_embed_and_index.sql`
5. `03_search.sql`
6. `04_create_oci_genai_credential.sql` — only before the remote-generation segment
7. `05_generate_answer.sql`


## One-time prerequisites

* An Autonomous AI Database running a 26ai-compatible service and a user permitted to create tables and vector indexes.
* An ONNX embedding model already loaded under `DOC_MODEL` (the default name used by the scripts), with a 384-dimensional output. `all-MiniLM-L12-v2` is a good fit; use the exact model name you imported.
* Upload one PDF to an Object Storage bucket and create a **read-only, time-limited pre-authenticated request (PAR)** for that single object. Paste its URL into `00_stage_pdf.sql`. A PAR lets the database fetch the PDF without displaying an Object Storage auth token.
* For the optional OCI Generative AI part, grant the schema outbound access to the regional GenAI host and create the vector credential from the template. Do this before the session, never live with real credential material on screen.

The scripts use `DBMS_VECTOR_CHAIN` consistently so the stage boundaries are obvious. In 26ai, equivalent vector utility operations are also exposed by `DBMS_VECTOR`; the interesting point is the composable hand-off between results, not which namespace is typed.

## Workshop material: The HTML document: Lewis Carroll, Alice’s Adventures in Wonderland (1865), Project Gutenberg eBook #11; original work public domain.

Source: Lewis Carroll, Alice’s Adventures in Wonderland (1865), Project Gutenberg eBook #11; original work public domain.


## Demo notes

* `00` is the Object Storage and HTML proof point.
* `01` change `max`, `overlap`, or `split`, then rerun the final query. Keep chunks beneath the 4,000-character embedding-input limit.
* `02` uses the database-resident ONNX model, so no external embedding call or API key is needed. It creates the HNSW index only after loading.
* `03` uses `FETCH APPROX` to make the vector-index path explicit. If your service/plan does not accept approximate syntax, replace it with `FETCH FIRST` for an exact scan.
* `05` demonstrates the results 

* `04` and `06` are optional: keep them off-screen until needed.


## Official references

Oracle documents the [PDF-to-text/chunks/embeddings sequence](https://docs.oracle.com/en/database/oracle/oracle-database/26/vecse/perform-chunking-with-embedding.html), [chunk parameters and metadata](https://docs.oracle.com/en/database/oracle/oracle-database/26/vecse/utl_to_chunks-dbms_vector_chain.html), [embedding providers](https://docs.oracle.com/en/database/oracle/oracle-database/26/vecse/utl_to_embedding-and-utl_to_embeddings-dbms_vector_chain.html), and [supported provider endpoints](https://docs.oracle.com/en/database/oracle/oracle-database/26/vecse/supported-third-party-provider-operations-and-endpoints.html).
