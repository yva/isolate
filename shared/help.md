# How to use auth!

## 0. add new YVA deployment, by URL or IP

**add.depl.sh name [ url | ip ]**

```bash
#examples:
[default][auth][~]$ add.depl.sh data-25 http://data-25.westeurope.cloudapp.azure.com/
[default][auth][~]$ add.depl.sh data-25 data-25.westeurope.cloudapp.azure.com
[default][auth][~]$ add.depl.sh data-25 1.2.3.4
```
**Warning!**
if this deployment work's internal hosts will be added from consul if not, only one default host mngr wil be added!!!

## 1. g  (aka - go)

Do console ssh connection to deployment

example:
```
[default][auth][~]$ g data-25 mngr0
[default][auth][~]$ g data-25 10.0.4.5
```

## 2. s  (aka search)

```
[auth1][~]# s aws

drugstore
------
100009  | 4.1.1.1          | aws-eu-prod

powerrangers
------
100007  | 3.1.1.1          | aws-eu-prod
100008  | 3.1.1.2          | aws-eu-reserve

------
Total: 3

[auth1][~]#
```

## delete yva deployments

```bash
[default][auth][~]$ del.depl.sh name
```


## manual operations: add server

Login as new auth user before.

```
[default][auth][~]$ auth-add-host --project starwars --server-name sel-msk-prod --ip 1.1.1.1
Database updated
```

## manual operations: del server

```bash
$ auth-del-host <server_id>
```

## add hosts in network

```bash
auth-add-host --project bigcorp --proxy-id 10001 --server-name au-prod-web1 --ip 192.168.1.1
auth-add-host --project bigcorp --proxy-id 10001 --server-name au-prod-web2 --ip 192.168.1.2
auth-add-host --project bigcorp --proxy-id 10001 --server-name au-prod-web3 --ip 192.168.1.3
```