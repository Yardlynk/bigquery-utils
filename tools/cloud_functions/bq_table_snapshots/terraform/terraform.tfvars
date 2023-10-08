snapshots = [
    {
        source_dataset_name       = "oms_raw_public"
        target_dataset_name       = "oms_raw_public_history"
        seconds_before_expiration = 5443200
        crontab_format            = "0 0 * * 0"
    },
    {
        source_dataset_name       = "default"
        target_dataset_name       = "default_history"
        seconds_before_expiration = 5443200
        crontab_format            = "0 0 * * 0"
    }  
]
project_id                  = "yardlink-data-prod"
aws_service_account         = "bq-data-snapshot@yardlink-data-prod.iam.gserviceaccount.com"
storage_project_id          = "yardlink-data-prod"
default_table_expiration_ms = 7776000000
aws_location                = "europe-west2"

