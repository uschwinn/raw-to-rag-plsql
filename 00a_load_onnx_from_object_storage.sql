-- One-time setup. Put the ONNX file in Object Storage and create a read-only PAR.
-- Oracle's prebuilt all_MiniLM_L12_v2.onnx is the intended 384-dimensional model.
-- A PAR means credential => NULL. For a private native Object Storage URL, supply
-- a DBMS_CLOUD credential name instead.

-- connect as app user and replace modell_name and model_url

begin
  dbms_vector.load_onnx_model_cloud(
    model_name => '&MODEL_NAME',
    credential => null,
    uri        => '&MODEL_URL'
  );
end;
/

-- check the model is loaded

select model_name, mining_function, algorithm, algorithm_type, model_size
from user_mining_models;

select model_name,
       attribute_name,
       attribute_type,
       data_type,
       vector_info
from user_mining_model_attributes
order by attribute_name;
