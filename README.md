# Chocolatey Automatic Package Updater
A Chocolatey Docker Image for automatically updating packages on Chocolately.

This is a docker image to automatically update packages I maintain on [chocolatey.org](http://chocolatey.org). 

* It uses _Powershell_ and a Mono build of _Chocolatey_ to pull website pages and get information like the version, release notes and download links.
* It then parses this information and uses template files to build the packages and push them to the repository. 
* The container will then send a push notification through _Pushover_ to my devices so I can be notified of when a package has been submitted.
* Additionally keeps `.ver` files to store the previously update version numbers so that it won't re-run the script on the next check unless the version has changed.

_This is provided for backup purposes and to document how to use Powershell to automate this task._

## Environment Variables
Used to configure the Container and protect secrets from being included in the github repository.
| Name | Type | Description |
| ---- | ---- | ----------- |
| DELAY | Integer | The delay in minutes to run this script. Don't set to execute this script only once. |
| AKEY | String | The Pushover Application Key |
| UKEY | String | The Pushover User Key |
| CKEY | String | The Chocolatey API Key to Push to the Public Repository |