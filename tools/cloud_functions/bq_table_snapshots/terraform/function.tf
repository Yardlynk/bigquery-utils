# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.34.0"
    }
  }
}

resource "random_id" "bucket_prefix" {
  byte_length = 8
}

##########################################
#          BQ Target Dataset             #
##########################################

resource "google_bigquery_dataset" "dataset" {
  for_each    = {for idx, val in var.snapshots: idx => val}
  project    = var.storage_project_id
  dataset_id = each.value.target_dataset_name
  location                    = var.aws_location
  default_table_expiration_ms = var.default_table_expiration_ms
}

# This stops the existing dataset being destroyed... Hopefully!
moved {
  from = google_bigquery_dataset.dataset
  to   = google_bigquery_dataset.dataset["0"]
}

moved {
  from = google_bigquery_dataset.dataset["0"]
  to   = google_bigquery_dataset.dataset
}

##########################################
#        GCS Bucket for CF code          #
##########################################

resource "google_storage_bucket" "bucket" {
  for_each    = {for idx, val in var.snapshots: idx => val}
  name                        = "${random_id.bucket_prefix.hex}-${each.value.target_dataset_name}-gcf-source"
  location                    = "US"
  uniform_bucket_level_access = true
}

##########################################
#          Pub/Sub Topics                #
##########################################

resource "google_pubsub_topic" "snapshot_dataset_topic" {
    for_each    = {for idx, val in var.snapshots: idx => val}
    name = "snapshot_dataset_topic_${each.value.target_dataset_name}"
}


resource "google_pubsub_topic" "bq_snapshot_create_snapshot_topic" {
    for_each    = {for idx, val in var.snapshots: idx => val}
    name = "bq_snapshot_create_snapshot_topic_${each.value.target_dataset_name}"
}

##########################################
#          Cloud Scheduler               #
##########################################

resource "google_cloud_scheduler_job" "job" {
  for_each    = {for idx, val in var.snapshots: idx => val}
  name     = "bq-snap-start-process_${each.value.target_dataset_name}"
  schedule = each.value.crontab_format

  pubsub_target {
    # topic.id is the topic's full resource name.
    topic_name = google_pubsub_topic.snapshot_dataset_topic[each.key].id
    data       = base64encode("{\"source_dataset_name\":\"${each.value.source_dataset_name}\",\"target_dataset_name\":\"${each.value.target_dataset_name}\",\"crontab_format\":\"${each.value.crontab_format}\",\"seconds_before_expiration\":${each.value.seconds_before_expiration},\"tables_to_include_list\":${var.tables_to_include_list},\"tables_to_exclude_list\":${var.tables_to_exclude_list}}")
  }
}

##########################################
#    bq_backup_fetch_tables_names CF     #
##########################################
data "archive_file" "bq_backup_fetch_tables_names" {
  for_each    = {for idx, val in var.snapshots: idx => val}
  type        = "zip"
  source_dir  = "../bq_backup_fetch_tables_names"
  output_path = "/tmp/bq_backup_fetch_tables_names_${each.value.target_dataset_name}.zip"
}

resource "google_storage_bucket_object" "bq_backup_fetch_tables_names" {
  for_each    = {for idx, val in var.snapshots: idx => val}
  name   = "bq_backup_fetch_tables_names_${each.value.target_dataset_name}.zip"
  # bucket = google_storage_bucket.bucket.name
  bucket = resource.google_storage_bucket.bucket[each.key].name
  source = data.archive_file.bq_backup_fetch_tables_names[each.key].output_path
}

resource "google_cloudfunctions_function" "bq_backup_fetch_tables_names" {
  for_each    = {for idx, val in var.snapshots: idx => val}
  name = "bq_backup_fetch_tables_names_${each.value.target_dataset_name}"

  runtime               = "python39"
  available_memory_mb   = 128
  entry_point           = "main"
  source_archive_bucket = resource.google_storage_bucket.bucket[each.key].name
  source_archive_object = google_storage_bucket_object.bq_backup_fetch_tables_names[each.key].name
  service_account_email = var.aws_service_account
  environment_variables = {
    DATA_PROJECT_ID            = each.value.storage_project_id
    PUBSUB_PROJECT_ID          = each.value.project_id
    TABLE_NAME_PUBSUB_TOPIC_ID = google_pubsub_topic.bq_snapshot_create_snapshot_topic[each.key].name
  }

  event_trigger {
    event_type = "providers/cloud.pubsub/eventTypes/topic.publish"
    resource   = google_pubsub_topic.snapshot_dataset_topic[each.key].id
  }
}

##########################################
#     bq_backup_create_snapshots CF      #
##########################################
data "archive_file" "bq_backup_create_snapshots" {
  for_each    = {for idx, val in var.snapshots: idx => val}
  type        = "zip"
  source_dir  = "../bq_backup_create_snapshots"
  output_path = "/tmp/bq_backup_create_snapshots_${each.value.target_dataset_name}.zip"
}

resource "google_storage_bucket_object" "bq_backup_create_snapshots" {
  for_each    = {for idx, val in var.snapshots: idx => val}
  name   = "bq_backup_create_snapshots_${each.value.target_dataset_name}.zip"
  bucket = google_storage_bucket.bucket[each.key].name
  source = data.archive_file.bq_backup_create_snapshots[each.key].output_path
}


resource "google_cloudfunctions_function" "bq_backup_create_snapshots" {
  for_each    = {for idx, val in var.snapshots: idx => val}
  name = "bq_backup_create_snapshots_${each.value.target_dataset_name}"

  runtime               = "python39"
  max_instances         = 100 # BQ allows a max of 100 concurrent snapshot jobs per project
  available_memory_mb   = 128
  entry_point           = "main"
  source_archive_bucket = google_storage_bucket.bucket[each.key].name
  source_archive_object = google_storage_bucket_object.bq_backup_create_snapshots[each.key].name 
  service_account_email = var.aws_service_account

  environment_variables = {
    BQ_DATA_PROJECT_ID = each.value.storage_project_id
    BQ_JOBS_PROJECT_ID = each.value.project_id
  }

  event_trigger {
    event_type = "providers/cloud.pubsub/eventTypes/topic.publish"
    resource   = google_pubsub_topic.bq_snapshot_create_snapshot_topic[each.key].id
  }
}




# output "debug" {
#   # value = data.archive_file.bq_backup_fetch_tables_names[*][1].output_path
#   # value = data.archive_file.bq_backup_fetch_tables_names
#   value = resource.google_storage_bucket.bucket[*][1]
# }