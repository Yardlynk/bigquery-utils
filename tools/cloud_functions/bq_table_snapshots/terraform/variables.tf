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

variable "project_id" {
  description = "GCP Project ID containing Cloud Functions and Pub/Sub Topics."
  type        = string
}

variable "storage_project_id" {
  description = "GCP Project ID containing BigQuery tables which will be snapshotted."
  type        = string
}

variable "region" {
  description = "GCP region in which to deploy Cloud Function."
  default     = "us-central1"
}

variable "aws_service_account" {
  description = "AWS service account email."
  type        = string
}

variable "aws_location" {
  description = "AWS Locations"
  type        = string
}

variable "default_table_expiration_ms" {
  description = "Default Table Expiration ms."
  type        = number
}

variable "tables_to_include_list" {
  description = "List of BigQuery table names to snapshot from the specified source_dataset_name. If this variable is set, only the tables listed will be snapshotted. If not set, all tables within the specified source_dataset_name will be snapshotted."
  type    = string
  default = "[]"
}

variable "tables_to_exclude_list" {
  description = "List of BigQuery table names to exclude when snapshotting tables within the specified source_dataset_name. If this variable is set, the tables listed will be skipped and NOT snapshotted."
  type    = string
  default = "[]"
}

variable "snapshots" {
    type = list(object({
        source_dataset_name = string
        target_dataset_name = string
        crontab_format = string
        seconds_before_expiration = number
        project_id                  = string
        storage_project_id          = string
        tables_to_exclude_list = optional(string, "[]")
        tables_to_include_list = optional(string, "[]")
    })) 
}
