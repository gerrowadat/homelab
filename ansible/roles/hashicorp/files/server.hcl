server {
  enabled = true
  bootstrap_expect = 3

  default_scheduler_config {
    preemption_config {
      batch_scheduler_enabled   = true
      service_scheduler_enabled = true
      system_scheduler_enabled  = true
    }
  }
}
