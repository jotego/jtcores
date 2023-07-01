#!/bin/bash
docker image build --file jtcore-base.df --tag jotego/jtcore-base .
docker image build --file jtcore13.df --tag jotego/jtcore13 /opt/altera
docker image build --file jtcore17.df --tag jotego/jtcore17 /opt/intelFPGA_lite
docker image build --file jtcore17x.df --tag jotego/jtcore17x .
docker login
docker push jotego/jtcore-base:latest
docker push jotego/jtcore13:latest
docker push jotego/jtcore17:latest
docker push jotego/jtcore17x:latest
