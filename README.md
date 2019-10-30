# Chocolatey Automatic Package Updater
A Chocolatey Docker Image for automatically updating packages on Chocolately.

This is a docker image to automatically update packages I maintain on [chocolatey.org](http://chocolatey.org). 

* It uses _Powershell_ and a Mono build of _Chocolatey_ to pull website pages and get information like the version, release notes and download links.
* It then parses this information and uses template files to build the packages and push them to the repository. 
* The container will then send a push notification through _Pushover_ to my devices so I can be notified of when a package has been submitted.
* Additionally keeps `.ver` files to store the previously update version numbers so that it won't re-run the script on the next check unless the version has changed.

> There are also environment variables for the Docker container so that sensitive information is not hardcoded in the docker container as well a delay variable for when the next check should be performed.

This is provided for backup purposes and to document how to use Powershell to automate this task.
