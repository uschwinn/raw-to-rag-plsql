-- Create one_time credential setup
-- Optional swap embedding provider (in-DB -> third-party): see script 06


BEGIN
    DBMS_VECTOR_CHAIN.DROP_CREDENTIAL('OCI_GENAI_CRED');
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

DECLARE
    jo JSON_OBJECT_T;
BEGIN
    jo := JSON_OBJECT_T();
    jo.put('user_ocid',        '<your_user_ocid>');
    jo.put('tenancy_ocid',     '<your_tenancy_ocid>');
    jo.put('compartment_ocid', '<your_compartment_ocid>');
    jo.put('private_key',      '<your_api_private_key>');
    jo.put('fingerprint',      '<your_api_key_fingerprint>');

    DBMS_VECTOR_CHAIN.CREATE_CREDENTIAL(
        credential_name => 'OCI_GENAI_CRED',
        params          => JSON(jo.to_string)
    );
END;
/

-- Verify only that it exists; never select or print credential contents.

select credential_name from user_credentials 
where credential_name = 'OCI_GENAI_CRED';
