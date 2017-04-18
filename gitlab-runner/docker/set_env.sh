#!/bin/bash

echo -e "
export JAVA_HOME=/opt/jdk
export M2_HOME=/opt/maven
export NODE_HOME=/opt/node
export GRADLE_HOME=/opt/gradle

export PATH=\$JAVA_HOME/bin:\$NODE_HOME/bin:\$GRADLE_HOME/bin:\$M2_HOME/bin:\$PATH
" >> /etc/profile
