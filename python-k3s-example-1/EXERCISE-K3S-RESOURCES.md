# Exercise for Exploring K3s Resources

This exercise walks through a couple `kubectl` commands to list supported resources, understand some of their properties and query supported fields in yaml file specifications.

Both of these sections simply dig into the configmaps resource but the same could be done for pods, namespaces, nodes, services, deployments, etc.

## kubectl api-resources

`kubectl api-resources` lists all of the resource types supported in k3s. The `-o wide` option is used below for some extended information.

```
$ kubectl api-resources -o wide | grep -iE "configmap|shortnames"
NAME                                SHORTNAMES   APIVERSION                        NAMESPACED   KIND                               VERBS                                                        CATEGORIES
configmaps                          cm           v1                                true         ConfigMap                          create,delete,deletecollection,get,list,patch,update,watch
```

Some takeaways from above are that we should use the string `ConfigMap` for `kind` but can query config map resources using the name `configmaps`, or short name `cm`, or the singularized name `configmap` (though this is not a best practice).

## kubectl explain

`kubectl explain` can be handy to look for supported properties and we can see the output includes the top-level fields that we set in [Example 1](./README.md).

```
$ kubectl explain configmaps | grep -E "^  (apiVersion|data|kind|metadata)"
  apiVersion	<string>
  data	<map[string]string>
  kind	<string>
  metadata	<ObjectMeta>
```

Run on your own without the `grep` or with `--recursive` to quickly review some of the supported properties for config maps.

```
kubectl explain configmaps
```

```
kubectl explain --recursive configmaps
```
