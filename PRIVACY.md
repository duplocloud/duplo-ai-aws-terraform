# Privacy

DuploCloud's privacy policy is at **<https://duplocloud.com/legal/privacy-policy/>**.

This code sends nothing to DuploCloud itself. The DuploCloud AI platform it installs contacts DuploCloud to validate
its license token, and the web UI sends product usage metrics only if a user opts in inside the product.

The chart's analytics collector is **off** by default here. Setting `helpdesk_analytics_collector_enabled = true` in the `helpdesk` values turns it on, and it then reports to DuploCloud.

See the chart's [PRIVACY.md](https://github.com/duplocloud/duplo-ai-helm/blob/main/PRIVACY.md) for the details.

Questions: **ai-reporting@duplocloud.net**.
