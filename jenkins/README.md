# jenkins-cronjob-monitor
I prefer to have cronjobs run with crontab instead of another application such as Jenkins. Because, what if Jenkins is down? Or what is someone is maintaining Jenkins and the business critical scripts aren't even on Jenkins?

Jenkins already allows this with the use of ecternal jobs. Limited as they are, they work.
Jenkins also offers a complicated often buggy solution to run on your server to manage these cronjobs. But you can probably guess by how I wrote this, that this solution is not for everyone.

Therefore, this simple script posts the cron output to a Jenkins job. In your crontab, you write:
jenkins-cron-wrap.sh "name-of-jenkins-job" <actual script + parameters>

* script works, output to Jenkins
* Script doesnt work, error log to Jenkins
* Jenkins down, script still runs and you can check your logs on your server

Why bother using Jenkins at all?
ONE place with an overview of everything is just easier - and we already have our java builds in Jenkins.

Bonus: In Jenkins you can see if the cronjob has succeeded. The python script in this directory allows you to see if the cron executed at all (in time)

Note: It requires you to add the following to the job description of all crons. It also assumes that all cronjob jobs in jenkins start with "crobjob-<nameofjob>"
```bash
cron string: 20 1 * * *
```

# How to use
To use this script, change the following placeholders:
<YOUR_JENKINS_URL>, <YOUR-JENKINS-USERNAME> and <YOUR-JENKINS-TOKEN>

In your crontab, you write:
<cronstring> jenkins-cron-wrap.sh "name-of-jenkins-job" <actual script + parameters>

In Jenkins you add an external job with the name "name-of-jenkins-job".

To keep structure of what builds and cronjobs, add "cronjob-" to each cronjob name. This also makes it easier to create a view for cronjobs.