---
name: '"I need help" issue template'
about: Open an issue if you need help or something is not working as you expect.
title: ''
labels: ''
assignees: ''

---

The most important part here for us is to understand your problem. So, please give us the more details you can. We don't want to be guessing, and you want to have a response soon, so let's make good use of the time and not spend days just gathering the information we need for the diagnostic.

Describe the deployment (required):
1. Is is based on the default `systemd` deployment, the alternate `docker-compose` one, a custom one of your own `k8s`, `ecs`, etc?
2. Version installed of each component used.
3. Tool used for reproducing the issue.

Describe the problem (required):

How to reproduce it (optional):
If you problem is related to the API, give us the step to reproduce it using api-mate.

Other references (optional):
If it is related to an integration, also specify the integration and the version of the plugin or component used.

Provide Logs (may be required):
Include the logs from the component that is failing.

NOTE: Request that do not provide the minimal information required won't be taken in consideration and will be immediately closed.
