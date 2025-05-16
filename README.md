# Project Overview

This repository contains a modular tweet sentiment analysis system, organized into six individual repositories under the `remla25-team1` organization:

* **app**: Front-end application and API gateway responsible for serving pages and forwarding model inference requests.
* **model-service**: Microservice for handling sentiment classification requests, interfacing with the preprocessing library and the trained model.
* **model-training**: Training pipeline to build and export sentiment classification models.
* **lib-ml**: Shared preprocessing library for text cleaning, tokenization, and feature extraction.
* **lib-version**: Versioning library to manage and expose the current application version.
* **operation**: Deployment and orchestration artifacts (e.g., Docker, Kubernetes manifests) for the end-to-end system.

Each component can be developed, tested, and deployed independently, yet they form a cohesive machine learning-powered web service.

## Install & Run

Make sure you have **Docker** and **Docker Compose** installed:  
[Install Docker & Docker Compose](https://docs.docker.com/compose/install/)

### 1. Clone the Repository

Clone the **operation** repository from GitHub (e.g., using SSH):

   ```bash
   git clone git@github.com:remla25-team1/operation.git
   cd operation
   ```

### 2. Start the Services
From the root of the **operation** repository, build and start all services using Docker Compose:

   ```bash
   docker compose up --build
   # or, if using the older syntax:
   docker-compose up --build
   ```

Once the containers are running, open your browser and go to [http://localhost:8080](http://localhost:8080) to access the application.


### 3. Stop and Clean Up

   ```bash
   docker compose down
   # or
   docker-compose down
   ```

## Use-Case: Tweet Sentiment Analysis

Our application features a simple interface where users can enter a tweet to analyze its sentiment. When submitted, the backend runs a sentiment analysis model and displays the predicted sentiment. The user then sees whether the tweet is positive or negative, and can confirm or correct this prediction. This feedback helps improve the model and makes the app more interactive and accurate over time.

### Negative Comment
![alt text](cases/negative.png)

[Original tweet available here](https://x.com/JtheCat3/status/1864351776868094126)

### Positive Comment
![alt text](cases/positive.png)

[Original tweet available here](https://x.com/TinuKuye/status/1719440898696630564)

### Correct Predictions
![alt text](cases/correction.png)

[Original tweet available here](https://x.com/TinuKuye/status/1719440898696630564)


## Related Repositories

* [app](https://github.com/remla25-team1/app)
* [model-service](https://github.com/remla25-team1/model-service)
* [model-training](https://github.com/remla25-team1/model-training)
* [lib-ml](https://github.com/remla25-team1/lib-ml)
* [lib-version](https://github.com/remla25-team1/lib-version)
* [operation](https://github.com/remla25-team1/operation)


## Progress Log

**model-service**: Implemented core sentiment analysis module in `model-service`, leveraging a baseline logistic regression model for binary classification, and designed the HTTP endpoint to accept raw comments and return sentiment labels.

**app(app-frontend, app-service)**: Developed the `app` front-end with React, integrated request forwarding logic to the `model-service`, and added client-side version display using the `lib-version` service.

**lib-version**: Created the `lib-version` library with semantic versioning support, implemented an HTTP server to expose version information.

**lib-ml**: Built the `lib-ml` preprocessing pipeline, integrated the library into `model-service` for consistent preprocessing.

**modle-training**: Completed the `model-training` pipeline: read datasets, trained models, and exported the model artifact for inference in `model-service`.

**operation**: Provides a simple Dockerfile setup along with clear documentation for running the entire system locally.

---