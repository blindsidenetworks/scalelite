---
name: '"I need help" issue template'
about: Open an issue if you need help or something is not working as you expect.
title: ''
labels: ''
assignees: ''

---

The most important part here for us is to understand your problem. So, please give us the more details you can. We don't want to be guessing nor have the time to go back and forth gathering information from you.

Start describing your deployment environment
Describe the deployment:
1. Is is based on the default `systemd` deployment, the alternate `docker-compose` one, a custom one of your own `k8s`, `ecs`, etc?
2. Version installed of each component used.
3. Tool used for reproducing the issue.

If you problem is related to the API, give us the step to reproduce it using api-mate.

If it is related to an integration, also specify the integration and the version of the plugin or component used.

Provide Logs:
Include the logs from the component that is failing.

NOTE: Request that do not provide this information won't be taken in consideration and will be immediately closed.
