# Drone package for Yunohost

[Drone](https://github.com/drone/drone) is a Continuous Delivery platform built
on Docker, written in Go.

## Requirements
A functional instance of [YunoHost](https://yunohost.org)

## Installation
From the command line:

`sudo yunohost app install -l Drone https://github.com/softinio/drone_ynh`

*Note*: Drone can only be installed at the root of a domain (see [issue 475](https://github.com/drone/drone/issues/475)).
