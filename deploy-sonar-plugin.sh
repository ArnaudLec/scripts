#!/bin/bash

SONAR_DIR=/opt/sonar
SONAR_PLUGINS_DIR=$SONAR_DIR/extensions/plugins
SONAR_LOG_DIR=$SONAR_DIR/logs
SONAR_USR=sonar
SONAR_GRP=adm

#DOC : Exits if an error occured during with the last command
function assert {
  if [ "$?" -ne "0" ] ; then
		echo "[ERROR] STOP an error occured"
		exit 127
	fi
}

if [ "$#" != 1 ] ; then
  echo "USAGE: $0 plugin-to-deploy.jar"
  exit 1
fi

PLUGIN_TO_DEPLOY=$1
echo "Deploying SonarQube plugin '$PLUGIN_TO_DEPLOY'..."
PLUGIN_VERSION=$(echo "$PLUGIN_TO_DEPLOY" | sed -nre 's/^[^0-9]*-(([0-9]+\.)*[0-9]+)\.jar$/\1/p' )
PLUGIN_NAME=$(echo "$PLUGIN_TO_DEPLOY" | sed -nre 's/^([^0-9]*)-(([0-9]+\.)*[0-9]+)\.jar$/\1/p' )
echo "Name: $PLUGIN_NAME, Version: $PLUGIN_VERSION"

for f in $SONAR_PLUGINS_DIR/*
do
  if [[ "$f" == *"$PLUGIN_NAME"* ]]
  then
    echo "Found old plugin $f"
    read -rp "Select operation: (b=backup, d=delete) " operation
    case $operation in
      "b") # Backup
        mv "$f" "$f.bak"
        assert
        ;;
      "d") # Delete
        rm "$f"
        assert
        ;;
      *) echo "Unknown operation '$operation'. Ignoring operation on existing plugin.";;
    esac
  fi
done

mv "$PLUGIN_TO_DEPLOY" "$SONAR_PLUGINS_DIR/"

chown "$SONAR_USR:$SONAR_GRP" "$SONAR_PLUGINS_DIR/$PLUGIN_NAME"*

read -rp "Restart sonar: (y/n) " restart
if [ "$restart" == "y" ]
then
  echo "Restarting SonarQube..."
  service sonar restart
  assert
  tail -n0 -f $SONAR_LOG_DIR/sonar.log | while read -r LOGLINE
  do
    [[ "${LOGLINE}" == *"SonarQube is up"* ]] && pkill -P $$ tail
  done
  echo "SonarQube started succesfully."
else
  echo "You need to restart the SonarQube server to enable the new plugin."
fi
