#!/usr/bin/python
# coding: utf-8

######################################
# Notice:
# ------
# To run this script, python version 2.7 is required (default at mac, check in terminal with python --version)
# Also required are following libs:
# - croniter
# - requests
#
# To test whether its installed:
# python -c "import croniter"
######################################

import requests
import xml.sax
import datetime
import sys
import croniter

# Set variables
ALLOW_MISSING = 0;
EXIT_CODE = 0;
TIME_FORMAT="%H:%M %d/%m/%Y"
JENKINS_URL="http://localhost:8080/"  #if on jenkins server
RSS_URL="%sview/Cronjobs/rssLatest" % (JENKINS_URL)

######################################
# NO NEED TO EDIT AFTER THIS POINT

# Set UTC offset to fix Jenkins bug (it does not specify the timezone in RSS - it uses UTC)
import time
ts = time.time()
utc_offset = (datetime.datetime.fromtimestamp(ts) - datetime.datetime.utcfromtimestamp(ts)).total_seconds()

# Fetches the cron string from the task description
def fetch_cron_string(url):
    for line in requests.get(url+'description').content.split('\n'):
        if line.lower().startswith('cron string: '):
            return line.lower().replace('cron string:', '').strip().rstrip()
    return False

# Utils
def underline(title, character='-'):
    print title
    print "%s" % (character * (len(title) +2))

def print_special(msg,warning=False, info=False):
    if warning:
        print '/!\ '+msg
    elif info:
        print '[i] '+msg
    else:
        print msg

# Checks if an execution executed in time according to cron string
def check_cron_string(cron, last_execution):
    global EXIT_CODE
    print "Cron string: %s" % (cron)
    now = datetime.datetime.now()
    last = datetime.datetime.strptime(last_execution, '%Y-%m-%dT%H:%M:%SZ')
    last = last + datetime.timedelta(seconds = utc_offset)
    cron = croniter.croniter(cron, now)
    last_cron_exec = cron.get_prev(datetime.datetime)
    # Check if executed in time and give 1 hour execution time for the last run
    if last_cron_exec > (last + datetime.timedelta(hours = 1)):
        if ALLOW_MISSING > 0:
            print "Missed execution time: %s" % (last_cron_exec.strftime(TIME_FORMAT))
            for i in range(ALLOW_MISSING - 1):
                last_cron_exec = cron.get_prev(datetime.datetime)
                if last_cron_exec <= last:
                    print "(%s) Missed execution time: %s" % (i+1, last_cron_exec.strftime(TIME_FORMAT))
                    if(i+1 > ALLOW_MISSING):
                        EXIT_CODE = 1
                        print_special("Did not execute in time!", warning=True)
        else:
            print_special("Missed execution: %s" % (last_cron_exec.strftime(TIME_FORMAT)), warning=True)
            EXIT_CODE = 1
    print "Last executed on: %s" % (last.strftime(TIME_FORMAT))

# Handler for the RSS XML parser for Jenkins XML
class RSSHandler( xml.sax.ContentHandler ):
    def __init__(self):
        self.CurrentData = ""
        self.type = ""
        self.title = ""
        self.link = ""
        self.id = ""
        self.published = ""
        self.updated = ""

    # Call when an element starts
    def startElement(self, tag, attributes):
        self.CurrentData = tag

    # Call when an elements ends
    def endElement(self, tag):
        if tag == 'entry':
            underline(self.title.split('#')[0])
            status=self.title.split('#')[1].split('(')[1][:-1]
            print_special("Last build status: %s" % (status), warning=(status is "stable"))
            url = self.id.replace('tag:hudson.dev.java.net,2008:', '')
            cron_string=fetch_cron_string(url)
            print url
            if not cron_string:
                print_special("No cron string found, can't monitor execution times.", info=True)
            else:
                check_cron_string(cron_string, self.updated)
            print '\n'
        self.CurrentData = ""

    # Call when a character is read
    def characters(self, content):
        if self.CurrentData == "type":
            self.type = content
        elif self.CurrentData == "title":
            self.title = content
        elif self.CurrentData == "link":
            self.link = content
        elif self.CurrentData == "id":
            self.id = content
        elif self.CurrentData == "published":
            self.published = content

###########################################
# Actual program

underline("Checking execution times", '=')

print "Executed on: %s" % (datetime.datetime.now().strftime(TIME_FORMAT))
print "Data source: %s" % (RSS_URL)

# Fetch the latest build RSS from Jenkins
r = requests.get(RSS_URL)

# Parse the latest build RSS with our custom build parser
xml.sax.parseString( r.content, RSSHandler() )

# Print overview and exit according to exit code
print "\n%s" % ("=" * 10)
if EXIT_CODE > 0:
    print_special("One or more cronjobs failed to execute!",warning=True)
else:
    print "All cronjobs executed in time."
sys.exit(EXIT_CODE)
