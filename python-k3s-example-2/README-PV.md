# Persistent Volume Primer

In k3s, many of the resources are ephemeral or brought up when needed and designed to be readily destroyed and brought back up from scratch when needed. However, this isn't useful if you plan to create data that needs to persist.

Commonly, you might want data to persist in a database or on a filesystem. But, if your pod's filesystem starts from scratch whenever a new pod is launched, what can you do?

Two solutions for persistent storage are databases and filesystems. However, a database will ultimately rely upon a filesystem for persistence.

Persistent volumes are like externally mounted drives in a pod where files can persist across pod lifetimes.

In k3s, the default storage for persistent volumes is supported by the "local path provisioner" service. As k3s is designed to be plug and play, there could be a replacement service to use as an alternative to the default k3s local path provisioner.

K3s official docs: [Volumes and Storage](https://docs.k3s.io/storage)

## Persistent Volume

A persistent volume (pv) can specify storage size, policy (`Retain` or `Delete`), and path. In the local path provisioner case, a persistent volume is simply a directory on the host computer.

## Persistent Volume Claim

A persistent volume claim binds some request for file storage resources to a persistent volume. The volume must be available when needed (or created dynamically when needed), have adequate size and match the type of storage requested.

In the case of local path provisioner, only ONE POD at a time is intended to access the persistent volume for writing. In k3s yaml terms, the `ReadWriteOnce` (`RWO`) access mode is supported but not `ReadWriteMany` (`RWX`). Additionally, `ReadOnlyMany` (`ROX`) has limited support based on the following caveat that also applies to `RWO`. The caveat is that any sharing with local path provisioner must be on the same node. In a single node cluster, this is a non-issue. However, suppose you have two host machines and each provides a node in a k3s cluster. In this case, any pods that wish to access a persistent volume must run on the same node where the persistent volume lives as the persistent volume exists on the host's filesystem. A couple of the implications are that if you intend to scale some resource and suppose you want read access to some large data valume then all the pods reading that volume with `ROX` must run on the same node. In the case of `RWO`, the behavior of k3s as of January, 2025, is that k3s doesn't ENFORCE that only a single pod can mount the directory `RWO` but this could change in the future and having multiple writers can be dangerous.

**Tip:** If you plan to scale your service beyond one pod, you could consider using an external database for your external storage needs or configuring a single database within k3s to handle the storage for all instances of your service and let that single service mount a persistent volume. Or, look into other storage options beyond what the local path provisioner supports.

## Exercises in Binding a PVC to a PV

There are multiple factors that come into play when a kubernetes deployment or pod wishes to use a PVC to claim a PV.

If dynamic storage is supported, then a PVC can implicitly create a PV. In this case, the PV will typically get a fairly generic name with some salt appended for uniqueness - like `pvc-266c1a11-2af2-41a6-8539-5c946f9df495`. Typically, the `persistentVolumeReclaimPolicy` will be `Delete` which means the data will go away when the PVC is deleted. (If the PVC auto-created the PV with `Delete` policy then the PV doesn't explicitly need to be deleted; it will be deleted along with its files as soon as the claim is deleted.) This could be a surprise if you are hoping for persistent data.

You can see properties of the default storage policy with the following command:

```
$ kubectl get storageclasses
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  56d
```

Note the other two options are that binding is to `WaitForFirstConsumer` versus `Immediate` and support for volume expansion is `false`.

An alternative is to create a PV that is designed to retain data using a policy of `Retain`. In the case of the file upload service, the PV yaml is specified as:

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: file-upload-pv
  namespace: default
spec:
  claimRef:
    namespace: default
    name: file-upload-pvc
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  hostPath:
    path: /usr/local/gigrouter/k3s/pv/file-server
    type: DirectoryOrCreate
  persistentVolumeReclaimPolicy: Retain
```

All the properties are pretty clear:
* Creating a `PersistentVolume`
* `file-upload-pv` is simply a chosen name but indicates both that this is for the the file upload service and is a persistent volume
* `default` is optional in this specific case but makes it clear the `default` namespace is used
* `claimRef` is also optional but helps ensure this PV will get tied to the intended PVC
* `1Gi` is the storage size, which is simply a common default
* `ReadWriteOnce` indicates the volume can't be used by multiple pods at once
* `local-path` indicates the local path provisioner is resonsible for managing the volume
* `path` specifies the path on the host filesystem
* `DirectoryOrCreate` means to use the directory if it exists or create it if needed
* `Retain` indicates that the directory shouldn't be cleared even if the PV is deleted

Then, the PVC yaml definition specifies similar information that must have compatible fields with the PVC and not specify a larger amount of storage than available:

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: file-upload-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
```

We can view k3s PV and PVC resources with:

```
kubectl -n default get pv
```

```
kubectl -n default get pvc
```

When the PV is first created, the general status will look like:

```
$ kubectl get pv
NAME             CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                     STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
file-upload-pv   1Gi        RWO            Retain           Available   default/file-upload-pvc   local-path     <unset>                          7s
```

Note the STATUS is `Available` but the CLAIM has a value.

If we didn't include the `claimRef` section, our PV would look like:

```
$ kubectl get pv
NAME             CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
file-upload-pv   1Gi        RWO            Retain           Available           local-path     <unset>                          178m
```

Whereas the first is "holding" the volume for something named `file-upload-pvc`, the 2nd is open to pretty much any request for a volume that's the proper type and fits within 1Gi.

Once the volume is in use, the output will look more like:

```
$ kubectl get pv
NAME             CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                     STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
file-upload-pv   1Gi        RWO            Retain           Bound    default/file-upload-pvc   local-path     <unset>                          3h1m
```

Where we note the status is `Bound`.

Similarly, we can see the PVC is `Bound` to the `file-upload-pv` `VOLUME`.

```
$ kubectl get pvc
NAME              STATUS   VOLUME           CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
file-upload-pvc   Bound    file-upload-pv   1Gi        RWO            local-path     <unset>                 14s
```

If we tear down the PVC, let's see what the volume looks like. Note that we have some cascading dependencies where the file upload deployment needs the PVC and the file upload service depends on the file upload deployment.

NOTE: If we simply tried to delete the PVC, the call would hang until the pod using the PVC had terminated.

Instead, let's just delete them all at once (we're not deleting the PV):

```
$ kubectl delete pvc/file-upload-pvc svc/file-service deployments.apps/file-service
```

Let's see what the PV looks like now:

```
$ kubectl get pv
NAME             CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM                     STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
file-upload-pv   1Gi        RWO            Retain           Released   default/file-upload-pvc   local-path     <unset>                          3h6m
```

We can see its status is `Released` but note the original status after creation was `Available`.

For our understanding, let's try to recreate the PVC and see if it will use our PV that's currently `Released`:

```
$ kubectl apply -f k3s/pvc.yaml 
persistentvolumeclaim/file-upload-pvc created

$ kubectl get pvc
NAME              STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
file-upload-pvc   Pending                                      local-path     <unset>                 7s
```

The PVC is `Pending`. We need to understand that k3s will hold off until this resource is needed in the case that we set `WaitForFirstConsumer`. We can confirm that with the following:

```
$ kubectl describe pvc file-upload-pvc  | grep -A 10 Events:
Events:
  Type    Reason                Age                  From                         Message
  ----    ------                ----                 ----                         -------
  Normal  WaitForFirstConsumer  8s (x19 over 4m31s)  persistentvolume-controller  waiting for first consumer to be created before binding
```

So, we also need to create our deployment which uses the PVC:

```
$ kubectl apply -f k3s/deployment-file-service.yaml 
deployment.apps/file-service created
```

Now, what do we see for the PVC?

```
$ kubectl get pvc
NAME              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
file-upload-pvc   Bound    pvc-433940f3-1d9f-4817-b307-4c5ee70b86ec   1Gi        RWO            local-path     <unset>                 6m54s
```

Now, it is `Bound` but the `VOLUME` doesn't look right. Above it is `pvc-433940f3-1d9f-4817-b307-4c5ee70b86ec` but originally this field was the expected `file-upload-pv`. Let's see if looking at our PVs will tell us anything:

```
$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM                     STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
file-upload-pv                             1Gi        RWO            Retain           Released   default/file-upload-pvc   local-path     <unset>                          21m
pvc-433940f3-1d9f-4817-b307-4c5ee70b86ec   1Gi        RWO            Delete           Bound      default/file-upload-pvc   local-path     <unset>
```

Interesting. There are two PVs both associated with `default/file-upload-pvc` but our original one is still `Released` and this auto-created one is marked `Bound`. Moreover, this auto-created one has the RECLAIM POLICY of `Delete`. Yikes! If we're hoping to maintain persistent data, we better get this right!

Let's delete and try again:

```
$ kubectl delete deployments.apps/file-service pvc/file-upload-pvc
deployment.apps "file-service" deleted
persistentvolumeclaim "file-upload-pvc" deleted
<long pause>
```

The command appears to hang for a while but is just a pause while resources are freed. Let's see what start our persistent volumes are in now:

```
$ kubectl get pvc
No resources found in default namespace.

$ kubectl get pv
NAME             CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM                     STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
file-upload-pv   1Gi        RWO            Retain           Released   default/file-upload-pvc   local-path     <unset>                          26m
```

It looks like we are back to where we were before we tried to reuse our PV.

We should have a few options to reuse our persistent data:

1. If we never deleted our PVC then it would still be bound to the PV. (But, it's too late for that with the command we already ran above.) But, we could simply choose never to delete any of our important PVCs and thus keep them "bound" to the corresponding PV.

2. If we choose to `edit` the PV, we can make it appear as `Available` again by restoring the `claimRef` section to its original values where, minimally, `uid` must be deleted.

3. Rather than manually editing, it's possible to make explicit patches to k3s resources. The following would delete the `uid` in the `claimRef` section with a `patch` command: `kubectl patch pv file-upload-pv --type='json' -p='[{"op": "remove", "path": "/spec/claimRef/uid"}]'` That command is harder to remember and editing a config should be pretty straightforward for a human. But, you could easily script various `patch` commands as part of launching or tearing down services.

4. If we delete the PV with `kubectl delete pv file-upload-pv` then our `Retain` policy should persist the files on disk and later recreation of the PV should create a fresh PV over the same populated directory.

**WARNING**: If you have important data in your persistent volume then you should consider backing it up from the host filesystem and not take for granted that files will persist when deleting a PV with `Retain` policy. If you didn't set your volume up carefully or there was some bug or change in behavior then you wouldn't want to run the risk of losing your files.

Let's look at the PV and see what we find for `claimRef` settings.

```
$ kubectl get pv file-upload-pv -o yaml | grep -A 7 claimRef
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: file-upload-pvc
    namespace: default
    resourceVersion: "474320"
    uid: ee3b52c1-f093-4472-bb63-e7af0da2c4f6
  hostPath:
```

One way to change this on-the-fly is with the following command. Note that `vi` will be the default editor but you can override this with, for example `export EDITOR=PROGNAME` (such as `export EDITOR=nano`, etc.)

```
kubectl edit pv file-upload-pv
```

Delete the `uid` from the claimRef section and then save the file.

Now, check the PV status:

```
$ kubectl get pv
NAME             CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                     STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
file-upload-pv   1Gi        RWO            Retain           Available   default/file-upload-pvc   local-path     <unset>                          29m
```

The `STATUS` is again `Available`.

Note that if we would have instead deleted the entire `claimRef` section we'd have the same situation as if we never made a forward reference to the claim we're expecting. Our PV would look like:

```
$ kubectl get pv
NAME             CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
file-upload-pv   1Gi        RWO            Retain           Available           local-path     <unset>                          3h18m
```

Again, note that without a forward reference to the anticipated `PVC` in the `PV` definition, the `PV` is more likely to get tied to some other `PVC` by accident. That is, the `Available` volume above could otherwise be claimed by any volume resource request that wants a volume <= 1Gi using `RWO` and using local path provisioner. (There's currently no way for the `PVC` to indicate it wants a volume with a `Retain` policy.)

Other concerns could be (1) if you forget to create the PV, (2) create the PV out of order, or (3) delete the PVC and don't clear the `uid` in the PV's `claimRef` as we demonstrated above then, in all the cases, the PVC could auto-create a PV. Without inspecting what the PVC is bound to (or being very careful with your config), you could end up with an auto-created PV with a `Delete` policy that won't retain your files.

In short: Always sanity check and verify your config.

## PV is Tied to the Node

As mentioned previously, since the persistent volume exists on a k3s host and if you have multiple nodes on multiple hosts in a cluster then your volumes are only available on the node where the particular volume is hosted.

Another consequence of this is that if you rename you node then you'll likely need to recreate any persistent volumes so they will be tied to the new node name.

If the node name does appear in the volume, it is also not editable. Though many k3s resources can be edited or later patched, some fields such as this are `immutable`. Another example of an immutable field is trying to change the storage class of a PV.

## PV and PVC Sizes

It's common to find that estimated resource usage might not be adequate for actual future usage. If you wished to change how much space you'd like to request, it would take many steps to, for example, specify 5Gi instead of 1Gi for a persistent volume.

As outlined in the steps above, you could delete both your PV and PVC and your data would persist so long as you set a policy of `Retain`. You could then update both your PV and PVC to use the updated 5Gi size.

Technically, the PVC is only specifying a minimum size so it just needs to find a compatible persistent volume that's at least the size requested and the storage usage can grow to whatever the PV allows.

The PV, on the other hand, is limited by the host filesystem available space so it might specify a size that might not be attainable as the host's filesystem fills up. The PV doesn't "reserve space" when it is created. In the same vein, there isn't necessarily quota enforcement that ensures that the specified 1Gi or 5Gi cap isn't exceeded. You might look into other quota options if your goal is to enforce a cap.

Finally, it was mentioned above that the default for volume expansion was `false`. Our adjustment above worked around this simply by suggesting the volume be deleted then recreated. If you were to try to edit or path the volume then changing the size would fail unless you used or created a different storage class that supported volume expansion (the storage class yaml would specify `allowVolumeExpansion: true` which defaults to `false if unspecified).
