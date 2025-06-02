## Repository Links:
<!-- REPO LINKS START -->
- **operation:** [repo](https://github.com/remla25-team1/operation) | No release out yet
- **model training:** [repo](https://github.com/remla25-team1/model-training) | latest release: [`v0.0.9-pre-20250526-001`](https://github.com/remla25-team1/model-training/releases/latest)
- **model service:** [repo](https://github.com/remla25-team1/model-service) | No release out yet
- **lib-ml:** [repo](https://github.com/remla25-team1/lib-ml) | latest release: [`v0.0.1-pre-20250516-001`](https://github.com/remla25-team1/lib-ml/releases/latest)
- **app:** [repo](https://github.com/remla25-team1/app) | latest release: [`v0.0.2`](https://github.com/remla25-team1/app/releases/latest)
- **lib-version:** [repo](https://github.com/remla25-team1/lib-version) | latest release: [`v0.1.4`](https://github.com/remla25-team1/lib-version/releases/latest)
<!-- REPO LINKS END -->

## Comments for A4:
Latest successful build can be found at https://github.com/remla25-team1/model-training/releases.
Files to inspect are our tests in: https://github.com/remla25-team1/model-training/tree/main/tests
And our testing Github workflow: https://github.com/remla25-team1/model-training/blob/main/.github/workflows/ml-test.yml
Furthermore, the Cookiecutter template is implemented in [```model-training```](https://github.com/remla25-team1/model-training)too (click to follow link).

## Comments for A3:
We plan on combining all manual steps of migrating the application to Kubernetes cluster in another playbook.

As an outsider you will not be able to do replicate this because you do not have a PAT that lets you pull build images of our application from GitHub. Instead, see the instructions we use for running in our[```README.md```](https://github.com/remla25-team1/operation/blob/main/README.md) (click to follow link).


## Comments for A2:

All steps work locally. Navigate into the ```operation``` directory and run ```vagrant up``` in the terminal (ensure VirtualBox is installed.) Logs of the setup will appear in the terminal. When done, run ```vagrant destroy``` for cleanup.

## Comments for A1:

Git tags to be reviewed are marked with __a1__

What can be reviewed:
- All repos. Though some functionality might be missing for some of them. 

What can not be reviewed:
- We did not manage to version the containers automatically. As of now we have to provide a git tag manually to trigger the workflow.