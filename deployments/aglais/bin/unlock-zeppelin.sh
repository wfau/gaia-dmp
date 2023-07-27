#!/bin/bash

sudo mv /etc/nginx/conf.d/maintenance.conf /etc/nginx/conf.d/maintenance.backup
sudo mv /etc/nginx/conf.d/zeppelin.backup /etc/nginx/conf.d/zeppelin.conf
sudo service nginx restart
