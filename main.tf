terraform {
  required_providers {
    circleci = {
      source  = "CircleCI-Public/circleci"
      version = "0.1.1"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

variable "circleci_token" {
  description = "CircleCI API token"
  type        = string
  sensitive   = true
}

variable "organization_id" {
  description = "Org name"
  type        = string
  sensitive   = true
}

variable "organization_name" {
  description = "GitHub organization or username"
  type        = string
  default     = "you org here"
}

# Provider will use CIRCLECI_TOKEN environment variable
provider "circleci" {
  # Token is read from CIRCLECI_TOKEN environment variable
}

# Get all projects using v1.1 API
data "http" "projects_v1" {
  url = "https://circleci.com/api/v1.1/projects"
  
  request_headers = {
    "Circle-Token" = var.circleci_token
    "Accept"       = "application/json"
  }
}

locals {
  # Parse v1.1 API response
  projects_v1 = try(jsondecode(data.http.projects_v1.response_body), [])
  
  # Filter projects for your organization
  org_projects = [
    for project in local.projects_v1 : project
    if project.username == var.organization_name
  ]
  
  # Create a clean map of projects
  projects_map = {
    for project in local.org_projects :
    project.reponame => {
      name           = project.reponame
      slug           = "gh/${var.organization_name}/${project.reponame}"
      vcs_url        = try(project.vcs_url, "")
      language       = try(project.language, "")
      default_branch = try(project.default_branch, "main")
    }
  }
}

# Fetch detailed info for each project using CircleCI provider
data "circleci_project" "detailed" {
  for_each = local.projects_map
  slug     = each.value.slug
}

# Outputs
output "organization_summary" {
  value = {
    organization    = var.organization_name
    total_projects  = length(local.projects_map)
    projects_found  = keys(local.projects_map)
  }
  description = "Organization summary with all project names"
}

output "all_projects_with_ids" {
  value = {
    for name, project in data.circleci_project.detailed :
    name => {
      id   = project.id
      name = project.name
      slug = local.projects_map[name].slug
    }
  }
  description = "All projects with their CircleCI IDs"
}

output "project_names_and_ids" {
  value = {
    for name, project in data.circleci_project.detailed :
    name => project.id
  }
  description = "Simple mapping of project names to IDs"
}

output "project_list" {
  value = [
    for name, info in local.projects_map : {
      name           = name
      slug           = info.slug
      language       = info.language
      default_branch = info.default_branch
    }
  ]
  description = "List of all projects with basic info"
}

# Debug output to see raw API data (optional)
output "debug_total_projects_from_api" {
  value       = length(local.projects_v1)
  description = "Total projects returned by API across all organizations"
}

output "debug_filtered_projects_count" {
  value       = length(local.org_projects)
  description = "Projects filtered for your organization"
}

# ================== trying adding a schedule ===================


