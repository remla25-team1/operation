## Repository Links:

operation: https://github.com/remla25-team1/operation

model training: https://github.com/remla25-team1/model-training

model service: https://github.com/remla25-team1/model-service

lib-ml: https://github.com/remla25-team1/lib-ml

app: https://github.com/remla25-team1/app

lib-version: https://github.com/remla25-team1/lib-version

## Comments for A3:
We plan on combining all manual steps of migrating the application to Kubernetes cluster in another playbook.

As an outsider you will not be able to do replicate this because you do not have a PAT that lets you pull build images of our application from GitHub. Instead, see the instructions we use for running in our[```README.md```](https://github.com/remla25-team1/operation/blob/main/README.md`) (click to follow link).


## Comments for A2:

All steps work locally. Navigate into the ```operation``` directory and run ```vagrant up``` in the terminal (ensure VirtualBox is installed.) Logs of the setup will appear in the terminal. When done, run ```vagrant destroy``` for cleanup.

## Comments for A1:

Git tags to be reviewed are marked with __a1__

What can be reviewed:
- All repos. Though some functionality might be missing for some of them. 

What can not be reviewed:
- We did not manage to version the containers automatically. As of now we have to provide a git tag manually to trigger the workflow. 

