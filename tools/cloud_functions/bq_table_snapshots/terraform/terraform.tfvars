snapshots = [
    {
        source_dataset_name       = "oms_raw_public"
        target_dataset_name       = "oms_raw_public_history"
        seconds_before_expiration = 5443200
        crontab_format            = "0 0 * * 1"
        project_id                  = "yardlink-data-prod"
        storage_project_id          = "yardlink-data-prod"
        tables_to_exclude_list      = "['versions', 'sent_emails']"
    },
    {
        source_dataset_name       = "default"
        target_dataset_name       = "default_history"
        seconds_before_expiration = 5443200
        crontab_format            = "0 0 * * 1"
        project_id                  = "yardlink-data-prod"
        storage_project_id          = "yardlink-data-prod"
    }  
]
project_id                  = "yardlink-data-prod"
aws_service_account         = "bq-data-snapshot@yardlink-data-prod.iam.gserviceaccount.com"
storage_project_id          = "yardlink-data-prod"
default_table_expiration_ms = 5443200
aws_location                = "europe-west2"
