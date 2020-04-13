# isolate

[![Gitter chat](https://badges.gitter.im/gitterHQ/gitter.png)](https://gitter.im/isolate_bastion/Lobby)
[![Telegram chat](https://camo.githubusercontent.com/5cd5c1cbf375ddec552e7224d81c3da18a11beb3/68747470733a2f2f706174726f6c617669612e6769746875622e696f2f74656c656772616d2d62616467652f636861742e706e67)](https://t.me/joinchat/BK6B5UH2Wfqie3fsJz_dIg)

![Image](main.png)

AUTHENTICATION SERVER 

The idea behind Isolate is that we should somehow manage how do people get access to our servers.
How can we make this process more secure?
How could we prevent a system from being compromised when someone lost the laptop with ssh key.
What would we do in case someone quits the company - is there an alternative to just changing all passwords, keys, etc? 

1. Isolate adds OTP 2FA to SSH login. It could be hardware YubiKey or Google Authenticator app. If someone lost the password - OTP key is here and the intruder can't get access to the bastion host.

2. Users don't get direct access to endpoint servers - they go there through Isolate server,  the system tracks their actions.

3. You can easily manage access to the bastion server - add/remove users, etc.

Technically you should generate and place the bastion host key on endpoint servers, and users will get regular access to Isolate server with the sudoer access to ssh command.

Once they want to connect to the endpoint server, the system executes ssh command and ssh client running with privileged user permissions gets server key and using it the system gets access to the server we need to get access to.

## Supports

* [OTP](https://en.wikipedia.org/wiki/One-time_password) (counter and time based) 2FA algorithms
* SSH sessions logging

## Requirements

* Fresh CentOS 7 / Ubuntu 16.04 / Ubuntu 18.04 / Debian 9 setup
* [Ansible](http://docs.ansible.com/ansible/intro_installation.html) 2.3+ for
install or update

## INSTALL

for ubuntu:
setup host and user at:

`ansible/hosts.ini`

and run:

```bash
#install all from scratch
make auth-all

# deploy only auth deployment (or update auth settings, groups fexample)
make auth-deploy

```

it's possible to restart server after install

### Test install
Creates Ubuntu 18.04 vagrant host with auth installed
## Warning !!!
Test host will contain PRODUCTION keys ( if you have access to azure keyvaut), so dont forget to destroy test VM!!!

```bash
# create Ubuntu 18.04 vagrant host with auth
make up

# test only auth deployment (or update auth settings, groups fexample)
make deploy

#remove all
make clean

#test conneciton to remote auth host
make auth-test
```

### SSH
edit

`/etc/ssh/sshd_config`:
```
# AuthorizedKeysFile /etc/keys/%u_authorized_keys
PermitRootLogin without-password
PasswordAuthentication yes
GSSAPIAuthentication no
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
UseDNS no
MaxStartups 48:20:300
TCPKeepAlive yes
ClientAliveInterval 36
ClientAliveCountMax 2400
```

```
systemctl restart sshd
systemctl status sshd
```

### OTP

add to

`/etc/pam.d/sshd` (`/etc/pam.d/common-auth` on debian/ubuntu):
```
auth       required     pam_oath.so usersfile=/etc/oath/users.oath window=20 digits=6
```

Example:
```
#%PAM-1.0
auth	   required     pam_sepermit.so
auth	   substack     password-auth
auth       required     pam_oath.so usersfile=/etc/oath/users.oath window=20 digits=6
auth	   include	    postlogin
...>
```

```
sed -i -e 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
```

add to

`/etc/ssh/sshd_config`

```
Match Group auth
    AuthenticationMethods keyboard-interactive
```
```
systemctl restart sshd
systemctl status sshd
```

## Management

#### load auth environment
```
# source /etc/bashrc

## OR debian/ubuntu:

# source /etc/bash.bashrc
```

#### add user
```
# auth-add-user username
```

#### generate otp
```
# Time-Based (Mobile and Desktop apps)
gen-oath-safe username totp

# Counter-Based (Yubikey and Mobile apps)
gen-oath-safe username hotp

# and append user secret to /etc/oath/users.oath
# Example: HOTP username - d7dc876e503ec498e532c331f3906153318ec565
```

```
mkdir -p /etc/oath
touch /etc/oath/users.oath
chmod 0600 /etc/oath/users.oath
echo '<user oath record above>' >> /etc/oath/users.oath
```

#### local user ssh config template

append to

top of

 `~/.ssh/config`
```
Host auth
    HostName 1.2.3.4
    Port 22
    User <username>
    ForwardAgent no
    ControlPath ~/.ssh/%r@%h:%p
    ControlMaster auto
    ControlPersist 3h
```

Persistent connection - for easy connection reopen without OTP and password prompt. (3h hours inactive timeout)

### Access and groups

  * Для разделения доступа к разным разверткам, в ISOLATE все хосты разделены на группы
    * default (dev & test развертывания, доступ юда автоматически выдается если пользователь добален через `auth-add-user`), unix группа **auth**
    * prod ( saas & mts saas ), unix группа **prod**
    * inf ( infrastructure hosts ), unix группа **inf**
    * suppport ( развертки клиентов ), unix группа **support**
  * Каждая группа использует свою пару  приватный/публичный ключ, и каждая группа это отедльная Redis база
  * Для активации группы пользователь должен вызвать функцию `ag [group]`в shell, если группу не указать выберется default. После перехода меняются хосты доступные функциям `g` && `s` (переключение между группами доступно любому пользователю), но 
  * Для выдачи пользователю прав на ssh к машинам в группе хостов, администратор должен добавить пользователя в соотвествующую unix-группу `sudo usermod -a -G username prod`.
  * Состав и приватные ключи групп регулируются тут: *ansible/roles/deploy/vars/main*.yml. Приватные ключи получаются их Azure KeyVault, настройки тут *yva.env.json*

### Hosts & yva deployments operations

#### add yva deployment 
it works if deployment is up and consul inside running propertly

```bash
add.depl.sh name url
 - or - 
add.depl.sh name ip
```

#### delete yva deployments

```bash
del.depl.sh name
```

#### manual add server

Login as new auth user before.

```
$ auth-add-host --project starwars --server-name sel-msk-prod --ip 1.1.1.1
Database updated
```

#### manual del server
```
$ auth-del-host <server_id>
```

#### test data
```
auth-add-host --project starwars --server-name sel-msk-prod --ip 1.1.1.1
auth-add-host --project starwars --server-name sel-spb-reserve --ip 1.1.1.2
auth-add-host --project starwars --server-name sel-spb-dev --ip 1.1.1.3

auth-add-host --project tinyfinger --server-name do-ams3-prod --ip 2.1.1.1
auth-add-host --project tinyfinger --server-name do-nyc-dev --ip 2.1.1.3

auth-add-host --project powerrangers --server-name aws-eu-prod --ip 3.1.1.1
auth-add-host --project powerrangers --server-name aws-eu-reserve --ip 3.1.1.2

# custom host/port/user options
auth-add-host --project drugstore --server-name aws-eu-prod --ip 4.1.1.1 --port 25 --user dealer --nosudo
```


### Host behind ssh proxy (client side bastion)

`nc`/`netcat` need to be installed to bastion host.
Or you can try use `-W host:port` options for ssh,
but on old Centos/Ubuntu this not work properly (old sshd versions).

You can use insecure proxy host for connections to other servers safely
(not need private keys on client side bastion-host),
Over `ProxyCommand` established sub ssh session with all authentication steps.

```
## add proxy
auth-add-host --project bigcorp --server-name au-prod-bastion --ip 45.45.45.45 --port 2232
Database updated: 10001

# and use this id (10001) as proxy to other hosts

## add hosts in network
auth-add-host --project bigcorp --proxy-id 10001 --server-name au-prod-web1 --ip 192.168.1.1
auth-add-host --project bigcorp --proxy-id 10001 --server-name au-prod-web2 --ip 192.168.1.2
auth-add-host --project bigcorp --proxy-id 10001 --server-name au-prod-web3 --ip 192.168.1.3
```

This ability useful for `Amazon VPC`
or other `VPC` provider with limited global internet ips and internal networking setup.

Also you can setup separate VPN host and use it as next hop, to ablie login to hosts over VPN.

### Project/Group default settings

```
$ auth-add-project-config projectname --proxy-id 10001 --port 2222
```

Host config override per project setting.

### S - aka search

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


### G - aka go

simple usage (just go to any server by ip with default user/port/key):
```
$ g 1.2.3.4
```

if connection not established as expected use `--debug`:
```
$ g 1.2.3.4 --port 3232 --user cheburajhka --debug
```

it puts `-v` option for `ssh` and show all helper/wrapper debug logs.

`--nosudo` - by default, ssh session opened with `sudo -i` (become root).
But on old FreeBSD or systems without `sudo` it not working as expected.
```
$ g 1.2.3.4 --nosudo
```


#### G with two arguments

example:
```
$ g bigcorp au-prod-web2
# g bigcorp 192.168.1.1
```

more complex example:
```
s bigcorp

bigcorp
------
100012  | 192.168.1.2      | au-prod-web2
100013  | 192.168.1.3      | au-prod-web3
100010  | 45.45.45.45      | au-prod-bastion
100011  | 192.168.1.1      | au-prod-web1

------
Total: 4
```

Use exist proxy by server_id (proxy_id == server_id):
```
# this line override all project and global defaults
$ g bigcorp 192.168.1.2 --user root --nosudo --port 4322 --proxy-id 100010
```

Set any accessable host as proxy:
```
g bigcorp 192.168.1.2 --proxy-host 33.22.44.88 --proxy-port 8022 --proxy-user pfwd
```

## Logs

```
/opt/auth/logs/${USER}/${USER}_${SSH_HOST}_${SSH_PORT}_${SSH_CONFIG}_1485110002_<uuid>.log
```

also with all logs, `ssh.py` creates `*.meta` files with JSON object.

## SSH Client configuration

`configs/defaults.conf`
```
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    TCPKeepAlive yes
    ServerAliveInterval 40
    ServerAliveCountMax 3
    ConnectTimeout 180
    ForwardAgent no
    UseRoaming no
    User support
    Port 22
    IdentityFile /home/auth/.ssh/id_rsa
```


### Autocomplete

Bash have a completition support.

Cron task under user `auth` update autocomplete data in `redis` every `*/1` minute.

Simple search (project) completition:
```
$ g tiny<tab><tab>
...
$ g tinyfinger
```
If you try `g project_name` without `host` argument:

 `a)` in project >1 servers. Action: show hosts list for this project.

 `b)` in project == 1 server. (only one server at project/group)

In `b` variant, helper lookups hosts list, and if only
one host in project/group -> just login to it.

You can disable blind mode by setting in you global/local `bashrc`:

```
export ISOLATE_BLINDE=false;
```

## User settings

This options can be added to local user `~/.bashrc`

```
ISOLATE_COLORS='true'
export ISOLATE_COLORS

# Search & Print fields for servers list
ISOLATE_SPF='server_id server_ip server_name'
export ISOLATE_SPF

# if only one server in project/group
ISOLATE_BLIND='false'
export ISOLATE_BLIND
```

## Debug options
`redis-dev` - open redis-cli with current `$ISOLATE_REDIS_PASS`
`--debug` - argument in all helpers

### Road Map

* Kibana logging
* Servers tags
* Web-Hooks
* NewRelic support
* Ansible inventory generate script
* SELinux Support
* Encrypted block device setup How-To
* Paranoic setup
* [Ideas?](mailto:ilya.yakovlev@me.com)
