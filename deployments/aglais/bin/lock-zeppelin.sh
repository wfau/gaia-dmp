#!/bin/bash

sudo mv /etc/nginx/conf.d/maintenance.backup /etc/nginx/conf.d/maintenance.conf
sudo mv /etc/nginx/conf.d/zeppelin.conf /etc/nginx/conf.d/zeppelin.backup
sudo service nginx restart
