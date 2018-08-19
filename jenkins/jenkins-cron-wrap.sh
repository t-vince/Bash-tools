#!/bin/bash -e
# example cron script to post logs to Jenkins
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin

#################################################################
# function   : init()
# Initialize script variables
function init() {
  log=`mktemp -t tmp.XXXX`
  timer=`date +"%s"`
  jenkins_server=<YOUR_JENKINS_URL> # e.g. http://127.0.0.1/
}

#################################################################
# function   : fetch_jenkins_crumb()
# job/$jenkins_job/postBuildResult
# see http://jenkins.example.com:8080/me/configure to get your username and API token
function fetch_jenkins_crumb() {
  jenkins_username="<YOUR-JENKINS-USERNAME>"
  jenkins_token="<YOUR-JENKINS-TOKEN>"
  CRUMB=$(wget -q --auth-no-challenge --user $jenkins_username --password $jenkins_token --output-document - $jenkins_server'/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)')
}

#################################################################
# function   : report()
# Make a XML report according to jenkins' format
function report () {
  result=$?
  timer=$((`date +"%s"` - $timer))

  echo $(printf '#%.0s' {1..80}) >> "$log"
  echo "`whoami`@`hostname -f` `date`: elapsed $timer second(s)" >> "$log"
  echo "exit code $result" >> "$log"

  # binary encode the log file for Jenkins
  msg=`cat "$log" | hexdump -v -e '1/1 "%02x"'`
  timer=$(($timer*1000)) # Note: Time in ms, not sec
  echo "<run><log encoding=\"hexBinary\">$msg</log><result>$result</result><duration>$timer</duration></run>" > "$log"

  # post the log to jenkins
  curl -s -X POST -H "$CRUMB" \
       -u "$jenkins_username:$jenkins_token" \
       -d @"$log" \
       "$jenkins_server/job/$jenkins_job/postBuildResult/"

  # Remove tmp file when finished
  rm $log
}

#################################################################
# Main program

# Fetch paramters
jenkins_job=$1
scripttorun=$2

init;
echo "CRONJOB: $scripttorun ${@:3}" >> "$log"

curl -s -m 5 -o "/dev/null" $jenkins_server;
if [ $? -ne 0 ];then
  echo " Jenkins unavailable; Running script without Jenkins logging"
  $scripttorun ${@:3}
else
  fetch_jenkins_crumb;
  trap report EXIT;

  echo $(printf '#%.0s' {1..80}) >> "$log"
  $scripttorun ${@:3} >> "$log"
fi

if [ $? -eq 0 ]; then
  exit 0
else
  echo "FAIL" >> "$log"
  exit 1
fi
