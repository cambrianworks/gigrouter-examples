# Python Example 2 Exercises

These exercises accompany Python example 2 for additional exploration of k3s features that could apply to example 2.

The exercises below:

* Explore extracting data from the file server's sqlite database
* Demonstrate copying files in/out of a pod
* Execute a bash shell in pod to demonstrate general debugging capabilities
* Make replicas of the md5sum service

## Extracting data from sqlite database

First, let's just grab a copy of the database from our host. We'll work with a copy so we don't have any issues with dual access to the file.

```
sudo apt install sqlite3
cp /usr/local/gigrouter/k3s/pv/file-server/metadata.db .
sqlite3 metadata.db
```

You should now be connected to the database. Let's look at the files we've saved data for.

```
.tables
SELECT * FROM files;
.exit
```

Sample output:

```
$ sqlite3 metadata.db 
SQLite version 3.31.1 2020-01-27 19:55:54
Enter ".help" for usage hints.
sqlite> .tables
files
sqlite> SELECT * FROM files;
1|pv.yaml|/data/uploads/pv.yaml|384|be1e9349ae1f398044e3a69574bf4b94
2|pvc.yaml|/data/uploads/pvc.yaml|195|90392c9102dc3c8a08684cfa4175540c
sqlite> .exit
```

Let's dump the database into SQL that could recreate it:

```
sqlite3 metadata.db ".dump" > backup.sql
```

```
$ cat backup.sql
PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                filename TEXT,
                path TEXT,
                size INTEGER,
                md5sum TEXT
            );
INSERT INTO files VALUES(1,'pv.yaml','/data/uploads/pv.yaml',384,'be1e9349ae1f398044e3a69574bf4b94');
INSERT INTO files VALUES(2,'pvc.yaml','/data/uploads/pvc.yaml',195,'90392c9102dc3c8a08684cfa4175540c');
DELETE FROM sqlite_sequence;
INSERT INTO sqlite_sequence VALUES('files',2);
COMMIT;
```

Restore `backup.sql` into a new database named `newdata.db`:

```
sqlite3 newdata.db < backup.sql
```

Export the contents of `files` table into a `.csv` file:

```
sqlite3 -header -csv metadata.db "SELECT * FROM files;" > files.csv
```

Examine the file:

```
$ cat files.csv 
id,filename,path,size,md5sum
1,pv.yaml,/data/uploads/pv.yaml,384,be1e9349ae1f398044e3a69574bf4b94
2,pvc.yaml,/data/uploads/pvc.yaml,195,90392c9102dc3c8a08684cfa4175540c
```

## Copying files in/out of pod (as well as other commands and redirects)

In the last example, we grabbed the sqlite database file from our host directory but this could be considered cheating. This assumed we were using a volume manager and that it simply kept files on the host. Let's try to copy the file out of the running pod.

**NOTE:** We're grabbing the file from an actively running server which could be updating the database. This first example runs some risk that the file could change during out copy.

From `file_service/app.py` we note this is the path used for the database:

```
DB_PATH = '/data/metadata.db'
```

From `deployment-file-service.yaml` we can see that `/data` does correpond to our persistent volume:

```
        volumeMounts:
        - mountPath: /data
          name: file-storage
      volumes:
      - name: file-storage
        persistentVolumeClaim:
          claimName: file-upload-pvc
```

Let's grab the file from the runnning pod with the `kubectl cp` command.

Recall that k3s has been configured for tab completion such that `file-<TAB>` should complete to the name of the `file-service` pod but we can also extract the name with the following:

```
$ kubectl get pods -o name | grep file
pod/file-service-844f485778-tgvpc
```

Let's use the `kubectl exec` command with `ls` to see what's in `/data`. Note that `--` is an accepted Unix convention that indicates that what follows is separate from flags to the given command.

```
$ kubectl exec file-service-844f485778-tgvpc -- ls -la /data
total 24
drwxr-xr-x 3 root root  4096 Jan 23 19:58 .
drwxr-xr-x 1 root root  4096 Jan 23 16:21 ..
-rw-r--r-- 1 root root 12288 Jan 23 19:58 metadata.db
drwxr-xr-x 2 root root  4096 Jan 23 19:58 uploads
```

**NOTE:** Executing `ls` or any command inside the pod requires the corresponding tool to have been installed and supported. Many images are Linux-based and support common tools however some pods may be based on images that are much more limited.

Now, let's grab the file and we'll add `_1cp` to the filename to simply to indicate something about how we obtained the file:

```
$ kubectl cp file-service-844f485778-tgvpc:/data/metadata.db metadata_1cp.db
tar: Removing leading `/' from member names
```

Let's also use some fancy Unix piping to grab a tarball of the entire `uploads` directory:

```
$ kubectl exec file-service-844f485778-tgvpc -- tar fcz - /data/uploads > uploads.tgz
tar: Removing leading `/' from member names

$ tar tvfz uploads.tgz 
drwxr-xr-x root/root         0 2025-01-23 19:58 data/uploads/
-rw-r--r-- root/root       195 2025-01-23 19:58 data/uploads/pvc.yaml
-rw-r--r-- root/root       384 2025-01-23 19:58 data/uploads/pv.yaml
```

The `tar` command that we ran specified `-` as the output filename which means to send output to standard out (`stdout`). The `z` option indicates the data should be compressed with `gzip`. And, finally, `/data/uploads` is the directory that we are tarring.

**NOTE:** The above redirect is commonly used and powerful but does assume that (1) the `kubectl` command is not adding anything extra to the standard output (`stdout`) and (2) that the `kubectl` command is not performing any CR/LF or other translations that could alter the output.

Let's look at the contents of the tarball:

```
$ tar tvfz uploads.tgz 
drwxr-xr-x root/root         0 2025-01-23 19:58 data/uploads/
-rw-r--r-- root/root       195 2025-01-23 19:58 data/uploads/pvc.yaml
-rw-r--r-- root/root       384 2025-01-23 19:58 data/uploads/pv.yaml
```

You'd use the `x` option to extract with `tar xvfz uploads.tgz`.

You could also copy the files from the container with the `kubectl cp` command:

```
$ kubectl cp file-service-844f485778-tgvpc:/data/uploads .
tar: Removing leading `/' from member names

$ ls -la
total 16
drwxrwxr-x 2 gigrouter gigrouter 4096 Jan 23 20:56 .
drwxrwxr-x 4 gigrouter gigrouter 4096 Jan 23 20:55 ..
-rw-rw-r-- 1 gigrouter gigrouter  195 Jan 23 20:56 pvc.yaml
-rw-rw-r-- 1 gigrouter gigrouter  384 Jan 23 20:56 pv.yaml
```

Previously, whenever we grabbed the sqlite metadata.db file, there was some worry of it being in active use and potentially changing while we copied it. If we instead access through the `sqlite3` command, it should perform appropriate locking. This means running the `sqlite3` command in the pod that's managing the database file.

Our Dockerfile installed `sqlite3` libraries for Python but not the `sqlite3` binary itself so we could either update our Dockerfile to install `sqlite3` or for this example, just install `sqlite3` into the running pod (this install will be lost when the pod exits and will not apply to pods launched in the future).

```
kubectl exec file-service-844f485778-tgvpc -- sh -c "apt update && apt -y install sqlite3 && sqlite3 /data/metadata.db \".backup '/tmp/metadata_2backup.db'\""
```

Then, copy the file out of the pod to your local directory:

```
kubectl cp file-service-844f485778-tgvpc:/tmp/metadata_2backup.db metadata_2backup.db
```

If you wanted the `sqlite3` binary in your file server pods by default, you could add the `apt install` to the `file_service/Dockerfile`:

```
FROM python:3.9-slim
WORKDIR /app
RUN apt update && apt install -y --no-install-recommends sqlite3 && rm -rf /var/lib/apt/lists/*
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

## Executing a bash shell in a pod

Given the usefulness of `kubectl exec` in the commands above, it's handy to know that you can often get working shell inside an active pod. Again, this makes some assumptions about what's supported in your pod and you might not be able to get a shell or might have to downgrade from `bash` to simply `sh`.

Let's give it a try here:

```
$ kubectl exec -it file-service-844f485778-tgvpc -- /bin/bash
root@file-service-844f485778-tgvpc:/app# ls -la /data
total 24
drwxr-xr-x 3 root root  4096 Jan 23 19:58 .
drwxr-xr-x 1 root root  4096 Jan 23 16:21 ..
-rw-r--r-- 1 root root 12288 Jan 23 19:58 metadata.db
drwxr-xr-x 2 root root  4096 Jan 23 19:58 uploads
root@file-service-844f485778-tgvpc:/app# exit
exit
```

Note the `-it` switches for an interactive terminal with stdin as a tty. Without those, we'd just execute `bash` then exit:

```
$ kubectl exec file-service-844f485778-tgvpc -- /bin/bash
$
```

The `kubectl exec --help` option tells us:

```
    -i, --stdin=false:
	Pass stdin to the container

    -t, --tty=false:
	Stdin is a TTY
```

## Making replicas of service

The example created a single instance of the `md5sum` service as well as a single instance of the `file` service. The ability to scale resources is one of the strengths of k3s. Let's make multiple instances of the `md5sum` service.

**NOTE:** As discussed in the [persistent volume readme](./README-PV.md), it can be tricky to create more than one instance of the `file` service on a k3s node since it's mounting a persistent volume and we found that local path provisioner only allows one pod at a time to mount it.

Let's see how the `md5sum` service is currently configured for replicas:

```
$ kubectl describe deploy md5sum-service  | grep Replicas:
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
```

Let's scale our deployment to 10 (or whatever instance count you'd like to try):

```
$ kubectl scale deployment md5sum-service --replicas=10
deployment.apps/md5sum-service scaled
```

There they are!

```
$ kubectl get pods
NAME                             READY   STATUS    RESTARTS   AGE
file-service-844f485778-tgvpc    1/1     Running   0          4h54m
md5sum-service-d7f489978-5q7zc   1/1     Running   0          29s
md5sum-service-d7f489978-8cjl2   1/1     Running   0          29s
md5sum-service-d7f489978-bl46q   1/1     Running   0          13d
md5sum-service-d7f489978-ft8w2   1/1     Running   0          29s
md5sum-service-d7f489978-jvvd7   1/1     Running   0          29s
md5sum-service-d7f489978-jwvnr   1/1     Running   0          29s
md5sum-service-d7f489978-n25z8   1/1     Running   0          29s
md5sum-service-d7f489978-tljp7   1/1     Running   0          29s
md5sum-service-d7f489978-w82g2   1/1     Running   0          29s
md5sum-service-d7f489978-zwrg5   1/1     Running   0          29s
python-app-6f874589dd-k2ld6      1/1     Running   0          10d
```

We previously mentioned `stern` as a tool to help monitor output of several pods at once. Let's take a look at our md5sum pods:

```
$ stern md5sum-service | grep "Running on http"
md5sum-service-d7f489978-5q7zc md5sum-service  * Running on http://10.42.0.80:5001/ (Press CTRL+C to quit)
md5sum-service-d7f489978-8cjl2 md5sum-service  * Running on http://10.42.0.81:5001/ (Press CTRL+C to quit)
md5sum-service-d7f489978-jwvnr md5sum-service  * Running on http://10.42.0.73:5001/ (Press CTRL+C to quit)
md5sum-service-d7f489978-zwrg5 md5sum-service  * Running on http://10.42.0.74:5001/ (Press CTRL+C to quit)
md5sum-service-d7f489978-w82g2 md5sum-service  * Running on http://10.42.0.77:5001/ (Press CTRL+C to quit)
md5sum-service-d7f489978-tljp7 md5sum-service  * Running on http://10.42.0.78:5001/ (Press CTRL+C to quit)
md5sum-service-d7f489978-ft8w2 md5sum-service  * Running on http://10.42.0.79:5001/ (Press CTRL+C to quit)
md5sum-service-d7f489978-jvvd7 md5sum-service  * Running on http://10.42.0.75:5001/ (Press CTRL+C to quit)
md5sum-service-d7f489978-n25z8 md5sum-service  * Running on http://10.42.0.76:5001/ (Press CTRL+C to quit)
```

We can see several private IP addresses running the service, each listening at TCP port 5001.

The md5sum service is still accessible at `http://localhost/md5`. Let's verify it is still working.

```
$ curl -X POST --data-binary "hi there" http://localhost/md5
{"md5sum":"fd33e2e8ad3cb1bdd3ea8f5633fcf5c7"}
```

We expect k3s to be distributing incoming calls amongst the multiple instances of the md5sum service.

Let's see what `replicas` looks like in our md5sum deployment:

```
$ kubectl get deploy md5sum-service -o yaml | grep -A 10 ^spec:
spec:
  progressDeadlineSeconds: 600
  replicas: 10
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: md5sum-service
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
```

What happens if we set the number of replicas to 0?

```
$ kubectl scale deployment md5sum-service --replicas=0
deployment.apps/md5sum-service scaled

$ kubectl get pods
NAME                             READY   STATUS        RESTARTS   AGE
file-service-844f485778-tgvpc    1/1     Running       0          5h16m
md5sum-service-d7f489978-5q7zc   1/1     Terminating   0          22m
md5sum-service-d7f489978-8cjl2   1/1     Terminating   0          22m
md5sum-service-d7f489978-bl46q   1/1     Terminating   0          13d
md5sum-service-d7f489978-ft8w2   1/1     Terminating   0          22m
md5sum-service-d7f489978-jvvd7   1/1     Terminating   0          22m
md5sum-service-d7f489978-jwvnr   1/1     Terminating   0          22m
md5sum-service-d7f489978-n25z8   1/1     Terminating   0          22m
md5sum-service-d7f489978-tljp7   1/1     Terminating   0          22m
md5sum-service-d7f489978-w82g2   1/1     Terminating   0          22m
md5sum-service-d7f489978-zwrg5   1/1     Terminating   0          22m
python-app-6f874589dd-k2ld6      1/1     Running       0          10d
```

```
$ curl -X POST --data-binary "hi there" http://localhost/md5
404 page not found
```

**TIP:** Scaling a deployment to 0 is a common method for debugging a problematic deployment or to take it down temporarily.

Let's restore it to 1 replica.

```
$ kubectl scale deployment md5sum-service --replicas=1
deployment.apps/md5sum-service scaled

$ kubectl get pods
NAME                             READY   STATUS    RESTARTS   AGE
file-service-844f485778-tgvpc    1/1     Running   0          5h26m
md5sum-service-d7f489978-97j5j   1/1     Running   0          3s
python-app-6f874589dd-k2ld6      1/1     Running   0          10d

$ curl -X POST --data-binary "hi there" http://localhost/md5
{"md5sum":"fd33e2e8ad3cb1bdd3ea8f5633fcf5c7"}
```
