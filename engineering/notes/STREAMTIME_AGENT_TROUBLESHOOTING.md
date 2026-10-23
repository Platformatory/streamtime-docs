# Streamtime Agent Troubleshooting Guide

## Common Issues and Solutions

### Issue 1: Helm Upgrade Reports Success But Deployment Not Updated

**Symptoms**:
- Workflow completes successfully
- Helm release shows correct chart version and values
- Deployment spec still has old image tag
- Pods still running old image

**Root Cause**: 
Helm's three-way merge algorithm may not update the deployment spec even when the Helm manifest is correct. This is a known Helm behavior when the live object differs from what Helm expects.

**Diagnosis**:
```bash
# Check Helm manifest (what Helm wants)
helm get manifest streamtime-agent -n streamtime-agent | grep "image:"

# Check actual deployment spec (what Kubernetes has)
kubectl get deployment streamtime-agent-streamtime-helm -n streamtime-agent \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# If they don't match, this is the issue
```

**Solution**:
The workflow now includes automatic fallback:
1. **Reality-based idempotency check**: Detects when deployment spec doesn't match
2. **PatchDeploymentImage fallback**: Automatically patches deployment to correct image

**Manual Fix** (if needed):
```bash
# Patch deployment directly
kubectl patch deployment streamtime-agent-streamtime-helm -n streamtime-agent \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"streamtime-agent","image":"registry:5000/streamtime/streamtime-agent:0.1.1764445821"}]}}}}'
```

**Prevention**:
- The workflow now handles this automatically
- No manual intervention needed

---

### Issue 2: RBAC Permission Errors

**Symptoms**:
- `VerifyUpgrade` activity fails
- Error: `cannot get resource "deployments" in API group "apps" in the namespace "streamtime-agent"`
- Error shows service account from `default` namespace

**Root Cause**:
- Service account exists in wrong namespace (`default` instead of `streamtime-agent`)
- ClusterRoleBinding references wrong namespace
- Missing or incorrect RBAC permissions

**Diagnosis**:
```bash
# Check service accounts
kubectl get serviceaccount -n streamtime-agent | grep streamtime-agent
kubectl get serviceaccount -n default | grep streamtime-agent

# Check ClusterRoleBinding
kubectl get clusterrolebinding streamtime-agent-streamtime-helm-cluster-admin -o yaml

# Check pod's service account
kubectl get pod -n streamtime-agent -l app.kubernetes.io/name=streamtime-helm \
  -o jsonpath='{.items[0].spec.serviceAccountName}'
```

**Solution**:
```bash
# Delete duplicate service account from default namespace
kubectl delete serviceaccount streamtime-agent-streamtime-helm -n default

# Verify service account exists in correct namespace
kubectl get serviceaccount streamtime-agent-streamtime-helm -n streamtime-agent

# Verify ClusterRoleBinding references correct namespace
kubectl get clusterrolebinding streamtime-agent-streamtime-helm-cluster-admin \
  -o jsonpath='{.subjects[0].namespace}'
# Should output: streamtime-agent
```

**Prevention**:
- Always deploy agent in `streamtime-agent` namespace
- Ensure Helm chart creates service account in correct namespace
- Verify ClusterRoleBinding references correct namespace

---

### Issue 3: VerifyUpgrade Takes Too Long

**Symptoms**:
- Workflow completes but verification takes 10+ minutes
- Workflow total time is 12+ minutes

**Root Cause**:
Default retry settings were too aggressive:
- 20 attempts × 30 seconds = 10 minutes
- Plus 180 second initial delay = ~13 minutes total

**Solution**:
Reduced retry settings:
- 5 attempts × 10 seconds = 50 seconds
- Plus 180 second initial delay = ~4 minutes total

**Configuration**:
```go
// In workflow
verifyInput := activities.VerifyUpgradeInput{
    MaxAttempts: 5,   // Reduced from 20
    RetryDelay:  10,  // Reduced from 30
}
```

**Customization**:
You can override defaults in workflow input:
```json
{
    "verify_delay_seconds": 120  // Reduce initial delay
}
```

---

### Issue 4: Workflow Fails During Self-Update

**Symptoms**:
- Workflow starts upgrading agent
- Pod running workflow gets terminated
- Workflow fails or hangs

**Root Cause**:
Updating the agent that's running the workflow causes pod termination. If the activity doesn't complete before pod termination, the workflow may fail.

**Solution**:
The workflow now handles this gracefully:
1. **Idempotent activities**: Can retry on new pod
2. **Reality-based idempotency**: Detects if upgrade already completed
3. **Optional scaling**: Scale up before upgrade to ensure another pod is available

**Best Practice**:
```json
{
    "scale_up_replicas": 2  // Scale to 2 replicas before upgrade
}
```

**How It Works**:
- Temporal workflows are durable (state stored in Temporal server)
- If pod terminates, workflow resumes on new pod
- Idempotency check detects if upgrade already completed
- Returns success immediately if already done

---

### Issue 5: Image Tag Not Found in Registry

**Symptoms**:
- Workflow fails with "no tags found" or "image tag not found"
- Error when querying registry for latest tag

**Root Cause**:
- Image not built/pushed to registry
- Registry URL incorrect
- Network connectivity issues

**Diagnosis**:
```bash
# Check registry contents
./scripts/list-registry-contents.sh

# Check registry connectivity
curl -s http://localhost:5001/v2/streamtime/streamtime-agent/tags/list | jq

# Check if image exists
docker pull registry:5000/streamtime/streamtime-agent:0.1.1764445821
```

**Solution**:
```bash
# Build and push image
./scripts/build-and-push-streamtime.sh

# Verify image is in registry
./scripts/list-registry-contents.sh | grep "streamtime/streamtime-agent"
```

**Prevention**:
- Always build and push before updating
- Use `./scripts/build-and-push-streamtime.sh` to ensure image is available
- Verify registry connectivity before running workflow

---

### Issue 6: Chart Version Not Found in Registry

**Symptoms**:
- Workflow fails with "chart version not found"
- Error when querying OCI registry for chart

**Root Cause**:
- Chart not pushed to registry
- Chart version format incorrect
- OCI registry not accessible

**Diagnosis**:
```bash
# Check registry contents
./scripts/list-registry-contents.sh | grep "streamtime-helm"

# Check OCI chart
helm show chart oci://localhost:5001/streamtime/streamtime-helm --version 0.1.1764445821
```

**Solution**:
```bash
# Build and push chart
./scripts/build-and-push-streamtime.sh

# Verify chart is in registry
./scripts/list-registry-contents.sh | grep "streamtime-helm"
```

**Prevention**:
- Always build and push chart with image
- Use `./scripts/build-and-push-streamtime.sh` to ensure chart is available
- Verify OCI registry connectivity

---

### Issue 7: Idempotency Check Incorrectly Reports Success

**Symptoms**:
- Workflow reports "upgrade already completed" but deployment has old image
- Idempotency check returns early but deployment not updated

**Root Cause** (Fixed):
Previously, idempotency check only compared Helm values, not actual deployment spec. Helm values may be correct but deployment spec may not be updated.

**Solution** (Implemented):
Reality-based idempotency check now compares:
1. Helm release chart version
2. **Actual deployment spec image tag** (from Kubernetes API)

Only if both match is upgrade considered complete.

**Verification**:
```bash
# Check if idempotency check is working
# Look for log: "Upgrade already completed - chart version and deployment image tag match"
kubectl logs -n streamtime-agent -l app.kubernetes.io/name=streamtime-helm | grep -i "idempotent"
```

---

### Issue 8: PatchDeploymentImage Fails

**Symptoms**:
- Workflow logs show "Helm upgrade did not update deployment spec"
- PatchDeploymentImage activity fails
- Deployment still has old image

**Root Cause**:
- RBAC permissions issue
- Deployment not found
- Container name incorrect

**Diagnosis**:
```bash
# Check workflow logs
kubectl logs -n streamtime-agent -l app.kubernetes.io/name=streamtime-helm | grep -i "patch"

# Check RBAC
kubectl auth can-i patch deployments --namespace=streamtime-agent \
  --as=system:serviceaccount:streamtime-agent:streamtime-agent-streamtime-helm

# Check deployment exists
kubectl get deployment streamtime-agent-streamtime-helm -n streamtime-agent
```

**Solution**:
1. Verify service account has permissions
2. Verify deployment name is correct
3. Verify container name is "streamtime-agent"

**Prevention**:
- Ensure ClusterRoleBinding grants cluster-admin permissions
- Verify service account is in correct namespace
- Use correct deployment and container names

---

## Debugging Commands

### Check Workflow Status

```bash
# List recent workflows
docker compose exec temporal temporal workflow list \
  --address temporal:7233 \
  --tls=false \
  --task-queue fleet-manager-tasks

# Show specific workflow
docker compose exec temporal temporal workflow show \
  --address temporal:7233 \
  --tls=false \
  --workflow-id "<workflow-id>"
```

### Check Deployment State

```bash
# Get deployment image
kubectl get deployment streamtime-agent-streamtime-helm -n streamtime-agent \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Get Helm release info
helm get all streamtime-agent -n streamtime-agent

# Compare Helm manifest vs deployment spec
helm get manifest streamtime-agent -n streamtime-agent | grep "image:" > /tmp/helm-image.txt
kubectl get deployment streamtime-agent-streamtime-helm -n streamtime-agent \
  -o jsonpath='{.spec.template.spec.containers[0].image}' > /tmp/k8s-image.txt
diff /tmp/helm-image.txt /tmp/k8s-image.txt
```

### Check Logs

```bash
# Python workflow logs
docker compose logs temporal-worker | grep -i "UpdateStreamtimeAgentWorkflow"

# Go workflow logs (from agent pod)
kubectl logs -n streamtime-agent -l app.kubernetes.io/name=streamtime-helm | grep -i "UpdateAgentWorkflow"

# Helm activity logs
kubectl logs -n streamtime-agent -l app.kubernetes.io/name=streamtime-helm | grep -i "HelmUpgrade"

# Patch activity logs
kubectl logs -n streamtime-agent -l app.kubernetes.io/name=streamtime-helm | grep -i "PatchDeploymentImage"
```

### Check Registry

```bash
# List all images and charts
./scripts/list-registry-contents.sh

# Check specific image tags
curl -s http://localhost:5001/v2/streamtime/streamtime-agent/tags/list | jq '.tags[]' | sort -V

# Check specific chart versions
helm show chart oci://localhost:5001/streamtime/streamtime-helm --versions | head -20
```

### Check RBAC

```bash
# Check service account
kubectl get serviceaccount streamtime-agent-streamtime-helm -n streamtime-agent -o yaml

# Check ClusterRoleBinding
kubectl get clusterrolebinding streamtime-agent-streamtime-helm-cluster-admin -o yaml

# Test permissions
kubectl auth can-i get deployments --namespace=streamtime-agent \
  --as=system:serviceaccount:streamtime-agent:streamtime-agent-streamtime-helm

kubectl auth can-i patch deployments --namespace=streamtime-agent \
  --as=system:serviceaccount:streamtime-agent:streamtime-agent-streamtime-helm
```

## Verification Checklist

After running an update workflow, verify:

- [ ] Workflow completed successfully
- [ ] Deployment spec has new image tag
- [ ] Pod is running new image
- [ ] Helm release has new chart version
- [ ] Helm manifest matches deployment spec
- [ ] No RBAC errors in logs
- [ ] VerifyUpgrade activity completed (check logs)
- [ ] No duplicate service accounts in default namespace

## Getting Help

If issues persist:

1. **Check Workflow History**: Review complete workflow execution in Temporal UI
2. **Check Logs**: Review both Python and Go workflow logs
3. **Verify State**: Compare Helm manifest vs deployment spec
4. **Check RBAC**: Verify service account permissions
5. **Review Documentation**: See [STREAMTIME_AGENT_UPDATE_WORKFLOW.md](STREAMTIME_AGENT_UPDATE_WORKFLOW.md)

## Related Documentation

- [Streamtime Agent Update Workflow](STREAMTIME_AGENT_UPDATE_WORKFLOW.md)
- [Building and Deploying Streamtime Artifacts](BUILDING_AND_DEPLOYING.md)
- [Workflow vs Deploy Script Comparison](WORKFLOW_VS_DEPLOY_SCRIPT_COMPARISON.md)




