#!/bin/bash
set -e

echo "Cloning all required repositories..."

git clone git@github.com:remla25-team1/operation.git
git clone git@github.com:remla25-team1/app.git
git clone git@github.com:remla25-team1/model-training.git
git clone git@github.com:remla25-team1/lib-ml.git
git clone git@github.com:remla25-team1/model-service.git
git clone git@github.com:remla25-team1/lib-version.git

echo "All repositories cloned!"