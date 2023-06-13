#!/bin/bash

sudo mv /etc/nginx/conf.d/zeppelin.conf /etc/nginx/conf.d/zeppelin.backup
sudo mv /etc/nginx/conf.d/maintenance.backup /etc/nginx/conf.d/maintenance.conf
sudo service nginx restart
