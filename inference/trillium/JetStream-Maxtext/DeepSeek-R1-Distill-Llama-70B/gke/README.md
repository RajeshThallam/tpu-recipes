# Inference benchmark of DeepSeek Distill R1 Llama 3.1 70B with JetStream MaxText Engine on TPU v6e (Trillium)

This recipe outlines the steps to benchmark the inference of a DeepSeek Distill R1 Llama 3.1 70B model using [JetStream](https://github.com/AI-Hypercomputer/JetStream/tree/main) with [MaxText](https://github.com/AI-Hypercomputer/maxtext) engine on an [TPU v6e Node pool](https://cloud.google.com/kubernetes-engine) with a single node.

## Orchestration and deployment tools

For this recipe, the following setup is used:

- Orchestration - [Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine)
- Job configuration and deployment - Helm chart is used to configure and deploy the
  [Kubernetes Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment).
  This job encapsulates the inference of the DeepSeek Distill R1 Llama 3.1 70B using JetStream MaxText Engine.
  The chart generates the deployment manifest, which adhere to best practices for using TPU v6e
  with Google Kubernetes Engine (GKE).

## Prerequisites

To prepare the required environment, complete the following steps:

1. Create a GKE Cluster with TPU v6e Node pool. You can choose to use either GKE Autopilot or GKE Standard, but for this recipe, we will use GKE Standard.
  ```bash
  gcloud container clusters create <CLUSTER_NAME> \
      --project=<PROJECT_ID> \
      --zone=<ZONE> \
      --workload-pool=<PROJECT_ID>.svc.id.goog \
      --addons GcsFuseCsiDriver
  ```

2. Create a TPU v6e slice node pool in the cluster.
  ```
  gcloud container node-pools create tpunodepool \
      --zone=<ZONE> \
      --num-nodes=1 \
      --machine-type=ct6e-standard-8t \
      --cluster=<CLUSTER_NAME> \
      --enable-autoscaling --total-min-nodes=1 --total-max-nodes=2 \
      --disk-size=500
  ```

GKE creates the following resources for the recipe:

- A GKE Standard cluster that uses Workload Identity Federation for GKE and has Cloud Storage FUSE CSI driver enabled.
- A TPU Trillium node pool with a `ct6e-standard-8t` machine type. This node pool has one node, eight TPU chips, and autoscaling enabled

Before running this recipe, ensure your environment is configured as follows:

- A GKE cluster with the following setup:
    - A TPU Trillium node pool with a `ct6e-standard-8t` machine type. 
    - Topology-aware scheduling enabled
- An Artifact Registry repository to store the Docker image.
- A Google Cloud Storage (GCS) bucket to store results.
  *Important: This bucket must be in the same region as the GKE cluster*.
- A client workstation with the following pre-installed:
   - Google Cloud SDK
   - Helm
   - kubectl
- To access the [DeepSeek Distill R1 Llama 3.1 70B model](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Llama-70B) through Hugging Face, you'll need a Hugging Face token. Follow these steps to generate a new token if you don't have one already:
   - Create a [Hugging Face account](https://huggingface.co/), if you don't already have one.
   - Click Your **Profile > Settings > Access Tokens**.
   - Select **New Token**.
   - Specify a Name and a Role of at least `Read`.
   - Select **Generate a token**.
   - Copy the generated token to your clipboard.


## Run the recipe

### Launch Cloud Shell

In the Google Cloud console, start a [Cloud Shell Instance](https://console.cloud.google.com/?cloudshell=true).

### Configure environment settings

From your client, complete the following steps:

1. Set the environment variables to match your environment:

  ```bash
  export PROJECT_ID=<PROJECT_ID>
  export REGION=<REGION>
  export CLUSTER_REGION=<CLUSTER_REGION>
  export CLUSTER_NAME=<CLUSTER_NAME>
  export GCS_BUCKET=<GCS_BUCKET>
  export ARTIFACT_REGISTRY=<ARTIFACT_REGISTRY>
  export JETSTREAM_MAXTEXT_IMAGE=jetstream-maxtext
  export JETSTREAM_MAXTEXT_VERSION=latest
  ```
  Replace the following values:

  - `<PROJECT_ID>`: your Google Cloud project ID
  - `<REGION>`: the region where you want to run Cloud Build
  - `<CLUSTER_REGION>`: the region where your cluster is located
  - `<CLUSTER_NAME>`: the name of your GKE cluster
  - `<GCS_BUCKET>`: the name of your Cloud Storage bucket. Do not include the `gs://` prefix
  - `<ARTIFACT_REGISTRY>`: the full name of your Artifact
    Registry in the following format: *LOCATION*-docker.pkg.dev/*PROJECT_ID*/*REPOSITORY*
  - `<JETSTREAM_MAXTEXT_IMAGE>`: the name of the JetStream MaxText image
  - `<JETSTREAM_MAXTEXT_VERSION>`: the version of the JetStream MaxText image

1. Set the default project:

  ```bash
  gcloud config set project $PROJECT_ID
  ```

### Get the recipe

From your client, clone the `tpu-recipes` repository and set a reference to the recipe folder.

```
git clone https://github.com/ai-hypercomputer/tpu-recipes.git
cd tpu-recipes
export REPO_ROOT=`git rev-parse --show-toplevel`
export RECIPE_ROOT=$REPO_ROOT/inference/trillium/JetStream-Maxtext/DeepSeek-R1-Distill-Llama-70B/gke
```

### Get cluster credentials

From your client, get the credentials for your cluster.

```
gcloud container clusters get-credentials $CLUSTER_NAME --region $CLUSTER_REGION
```

### Build and push a docker container image to Artifact Registry

To build the container, complete the following steps from your client:

1. Use Cloud Build to build and push the container image.

    ```bash
    cd $RECIPE_ROOT/docker
    gcloud builds submit --region=global \
        --config cloudbuild.yml \
        --substitutions _ARTIFACT_REGISTRY=$ARTIFACT_REGISTRY,_JETSTREAM_MAXTEXT_IMAGE=$JETSTREAM_MAXTEXT_IMAGE,_JETSTREAM_MAXTEXT_VERSION=$JETSTREAM_MAXTEXT_VERSION \
        --timeout "2h" \
        --machine-type=e2-highcpu-32 \
        --disk-size=1000 \
        --quiet \
        --async
    ```
  This command outputs the `build ID`.

2. You can monitor the build progress by streaming the logs for the `build ID`.
   To do this, run the following command.

   Replace `<BUILD_ID>` with your build ID.

   ```bash
   BUILD_ID=<BUILD_ID>

   gcloud beta builds log $BUILD_ID --region=$REGION
   ```

## Single TPU v6e Node Inference of DeepSeek Distill R1 Llama 3.1 70B

The recipe serves DeepSeek Distill R1 Llama 3.1 70B model using JetStream MaxText Engine on a single TPU v6e node.

To start the inference, the recipe launches JetStream MaxText Engine that does the following steps:
1. Downloads the full DeepSeek Distill R1 Llama 3.1 70B model checkpoints from [Hugging Face](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Llama-70B).
2. Convert the model checkpoints from Hugging Face format to JAX Orbax format.
3. Start the JetStream MaxText Engine server.
3. Inference is ready to respond to requests and run benchmarks

The recipe uses the helm chart to run the above steps.

1. Create Kubernetes Secret with a Hugging Face token to enable the job to download the model checkpoints.

    ```bash
    export HF_TOKEN=<YOUR_HUGGINGFACE_TOKEN>
    ```

    ```bash
    kubectl create secret generic hf-secret \
    --from-literal=hf_api_token=${HF_TOKEN} \
    --dry-run=client -o yaml | kubectl apply -f -
    ```

2. Run MMLU benchmark with the recipe

    a. Install the helm chart to unscan the model checkpoint and bring up the JetStream MaxText Engine server

    ```bash
    cd $RECIPE_ROOT
    helm install -f values.yaml \
    --set "volumes.gcsMounts[0].bucketName=${GCS_BUCKET}" \
    --set clusterName=$CLUSTER_NAME \
    --set job.image.repository=${ARTIFACT_REGISTRY}/${JETSTREAM_MAXTEXT_IMAGE} \
    --set job.image.tag=${JETSTREAM_MAXTEXT_VERSION} \
    --set "job.bucketName=${GCS_BUCKET}" \
    $USER-serving-deepseek-r1-model \
    $RECIPE_ROOT/serve-model
    ```

    b. To view the logs for the deployment, run
      ```bash
      kubectl logs -f deployment/$USER-serving-deepseek-r1-model-serving
      ```

    c. Verify if the deployment has started by running
      ```bash
      kubectl get deployment/$USER-serving-deepseek-r1-model-serving
      ```

    d. Once the deployment has started, you'll see logs similar to:
      ```bash
      Loading decode params from /gcs/deepseek-ai/DeepSeek-R1-Distill-Llama-70B/output/unscanned_ckpt/checkpoints/0/items
      restoring params from /gcs/deepseek-ai/DeepSeek-R1-Distill-Llama-70B/output/unscanned_ckpt/checkpoints/0/items
      WARNING:absl:The transformations API will eventually be replaced by an upgraded design. The current API will not be removed until this point, but it will no longer be actively worked on.

      Memstats: After load_params:
              Using (GB) 16.43 / 31.25 (52.576000%) on TPU_0(process=0,(0,0,0,0))
              Using (GB) 16.43 / 31.25 (52.576000%) on TPU_1(process=0,(1,0,0,0))
              Using (GB) 16.43 / 31.25 (52.576000%) on TPU_2(process=0,(0,1,0,0))
              Using (GB) 16.43 / 31.25 (52.576000%) on TPU_3(process=0,(1,1,0,0))
              Using (GB) 16.43 / 31.25 (52.576000%) on TPU_4(process=0,(0,2,0,0))
              Using (GB) 16.43 / 31.25 (52.576000%) on TPU_5(process=0,(1,2,0,0))
              Using (GB) 16.43 / 31.25 (52.576000%) on TPU_6(process=0,(0,3,0,0))
              Using (GB) 16.43 / 31.25 (52.576000%) on TPU_7(process=0,(1,3,0,0))
      ```

    e. Verify the server works as expected by running a sample request
      ```bash
      kubectl exec -it deployments/$USER-serving-deepseek-r1-model-serving -- python3 /JetStream/jetstream/tools/requester.py --tokenizer /maxtext/assets/tokenizer_llama3.tiktoken
      ```

      If everything is setup correctly, you should a response similar to this:
      ```
      Sending request to: 0.0.0.0:9000
      Prompt: My dog is cute
      Response: , but she's also
      ```

    f. To run MMLU, run the following command:

      ```bash
        kubectl exec -it deployments/$USER-serving-deepseek-r1-model-serving -- /bin/bash -c "JAX_PLATFORMS=tpu python3 /JetStream/benchmarks/benchmark_serving.py \
        --tokenizer=/maxtext/assets/tokenizer_llama3.tiktoken \
        --num-prompts 14037 \
        --dataset mmlu \
        --dataset-path /gcs/mmlu/data/test \
        --request-rate 0 \
        --warmup-mode sampled \
        --save-request-outputs \
        --num-shots=5 \
        --run-mmlu-dataset \
        --run-eval True \
        --model=llama-3 \
        --save-result \
        --max-input-length=1024 \
        --max-target-length=1536 \
        --request-outputs-file-path /gcs/benchmarks/mmlu_outputs.json"
      ```
    
    e. Stop the server and clean up the resources after completion by following the steps in the [Cleanup](#cleanup) section.

3. Run Math500 benchmark with the recipe

    a. Install the helm chart to bring up the JetStream MaxText Engine server. If you already have not unscanned the model checkpoint, set the flag `convert_hf_ckpt=true`.

      ```bash
      cd $RECIPE_ROOT
      helm install -f values.yaml \
      --set volumes.gcsMounts[0].bucketName=${GCS_BUCKET} \
      --set clusterName=$CLUSTER_NAME \
      --set job.image.repository=${ARTIFACT_REGISTRY}/${JETSTREAM_MAXTEXT_IMAGE} \
      --set job.image.tag=${JETSTREAM_MAXTEXT_VERSION} \
      --set convert_hf_ckpt=false \
      --set maxtext_config.max_target_length=2048 \
      --set maxtext_config.per_device_batch_size=20 \
      --set maxtext_config.quantize_kvcache=false \
      $USER-serving-deepseek-r1-model \
      $RECIPE_ROOT/serve-model
      ```
  
    b. To run Math500, run the following command:

      ```bash
      kubectl exec -it deployments/$USER-serving-deepseek-r1-model-serving -- /bin/bash -c "JAX_PLATFORMS=tpu python3 /JetStream/benchmarks/benchmark_serving.py \
      --tokenizer=/maxtext/assets/tokenizer_llama3.tiktoken \
      --num-prompts 500 \
      --dataset math500 \
      --request-rate 5 \
      --warmup-mode sampled \
      --save-request-outputs \
      --model=llama-3 \
      --save-result \
      --max-output-length 1024 \
      --request-outputs-file-path /gcs/benchmarks/math500_outputs.json"
      ```
    
    c. Stop the server and clean up the resources after completion by following the steps in the [Cleanup](#cleanup) section.

### Cleanup

To clean up the resources created by this recipe, complete the following steps:

1. Uninstall the helm chart.

    ```bash
    helm uninstall $USER-serving-deepseek-r1-model
    ```

2. Delete the Kubernetes Secret.

    ```bash
    kubectl delete secret hf-secret
    ```