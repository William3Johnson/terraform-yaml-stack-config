data "utils_component_config" "config" {
  component     = var.component
  stack         = var.stack
  namespace     = module.always.namespace
  tenant        = module.always.tenant
  environment   = module.always.environment
  stage         = module.always.stage
  ignore_errors = var.ignore_errors
  env           = var.env
}

locals {
  config = yamldecode(data.utils_component_config.config.output)

  remote_state_backend_type = try(local.config.remote_state_backend_type, "")
  backend_type              = try(coalesce(local.remote_state_backend_type, local.config.backend_type), "")

  # If `config.remote_state_backend` is not declared in YAML config, the default value will be an empty map `{}`
  backend_config_key = try(local.config.remote_state_backend, null) != null && try(length(local.config.remote_state_backend), 0) > 0 ? "remote_state_backend" : "backend"

  # This is used because the `?` operator in some instances (depending on the condition) changes the types of all items of the map to all `strings`
  backend_configs = {
    backend              = lookup(local.config, "backend", {})
    remote_state_backend = lookup(local.config, "remote_state_backend", {})
  }

  backend = local.backend_configs[local.backend_config_key]

  workspace            = lookup(local.config, "workspace", "")
  workspace_key_prefix = lookup(local.backend, "workspace_key_prefix", null)

  remote_state_enabled = ! var.bypass

  remote_states = {
    s3     = data.terraform_remote_state.s3
    remote = data.terraform_remote_state.remote
    bypass = [{ outputs = var.defaults }]
    static = [{ outputs = local.backend }]
  }

  remote_state_backend_key          = var.bypass ? "bypass" : local.backend_type
  computed_remote_state_backend_key = try(length(local.remote_states[local.remote_state_backend_key]), 0) > 0 ? local.remote_state_backend_key : "bypass"

  outputs = local.remote_states[local.computed_remote_state_backend_key][0].outputs
}
