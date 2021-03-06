#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
FROM ubuntu:trusty
MAINTAINER Tim Sutton<tim@linfiniti.com>

RUN  export DEBIAN_FRONTEND=noninteractive
ENV  DEBIAN_FRONTEND noninteractive
RUN  dpkg-divert --local --rename --add /sbin/initctl
#RUN  ln -s /bin/true /sbin/initctl

# Use local cached debs from host (saves your bandwidth!)
# Change ip below to that of your apt-cacher-ng host
# Or comment this line out if you do not with to use caching
ADD 71-apt-cacher-ng /etc/apt/apt.conf.d/71-apt-cacher-ng

RUN apt-get -y update
RUN echo "deb http://archive.ubuntu.com/ubuntu trusty main universe" > /etc/apt/sources.list
# socat can be used to proxy an external port and make it look like it is local
RUN apt-get -y install ca-certificates socat openssh-server supervisor rpl pwgen
RUN mkdir /var/run/sshd
ADD sshd.conf /etc/supervisor/conf.d/sshd.conf

# Ubuntu 14.04 by default only allows non pwd based root login
# We disable that but also create an .ssh dir so you can copy
# up your key. NOTE: This is not a particularly robust setup 
# security wise and we recommend to NOT expose ssh as a public
# service.
RUN rpl "PermitRootLogin without-password" "PermitRootLogin yes" /etc/ssh/sshd_config
RUN mkdir /root/.ssh
RUN chmod o-rwx /root/.ssh

#-------------Application Specific Stuff ----------------------------------------------------
RUN apt-get -y install nginx uwsgi uwsgi-plugin-python git python-virtualenv vim
# Alternative list for if installing uwsgi from pip
#RUN apt-get -y install nginx python-dev git python-virtualenv vim

ADD server-conf /home/web/server-conf
ADD REQUIREMENTS.txt /home/web/REQUIREMENTS.txt
# Note that ww-data does not have permissions
# for the django project dir - so we will copy it over and then set the 
# permissions in the start script. COPY is like ADD but does not 
# automatically unpack tarballs. We need to copy it as a tarball
# and then unzip it as www-data because docker copies files with
# uid/gid = 0
COPY django_project.tar.gz /tmp/django_project.tar.gz
RUN cd /home/web; tar xfz /tmp/django_project.tar.gz; chown -R www-data.www-data /home/web
# Run any additional tasks here that are too tedious to put in
# this dockerfile directly.
ADD setup.sh /setup.sh
RUN chmod 0755 /setup.sh
RUN /setup.sh

# Called on first run of docker - will run supervisor
ADD start.sh /start.sh
RUN chmod 0755 /start.sh

CMD /start.sh
