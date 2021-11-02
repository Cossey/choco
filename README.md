# Chocolatey Automatic Package Updater
A Chocolatey Script or Docker Image for automatically updating packages on Chocolately.

This can be used directly as a script or as a docker image to automatically update packages on [chocolatey.org](http://chocolatey.org).
Examples are for all the packages I maintain on community repository on chocolatey.org.

If the package has a problem or successfully updates, a push notification is sent out via Pushover. 
_This is provided for backup purposes and to document how to use Powershell to automate this task._

## Docker Container
Uses _Powershell_ and a Mono build of _Chocolatey_ run the script. Just set the [environment variables](#environment-variables) and you'll be good to go.

> **Warning: You may have issues pushing packages over 30 megabytes to the community repository using this image. This is an issue with Mono Chocolatey, the community repo endpoint and linux. You may have to run this on a windows system if you intend on including installer in your packages instead of download links (shims).**

## Script Only
You can also use these scripts directly instead of in a docker container (ie on Windows). You will need to ensure the following:
* Powershell Core 7+ is installed
* `Install-Module -Name PowerShellPushOver` to install Pushover support.
* Set the `DATAPATH` environment variable to a valid windows folder path (it is set to `/data` which is only valid in linux).

Set the environment variables and execute the `main.ps1` script to perform the package building.

*You can use the [Non-Sucking Service Manager](https://nssm.cc) to run this script as a service and to pass environment variables like `DELAY` to automatically run this script every `x` minutes.*

## Environment Variables
Used to configure the Container and protect secrets from being included in the github repository.
| Name              | Type    | Description                                                                                                            |
| ----------------- | ------- | ---------------------------------------------------------------------------------------------------------------------- |
| DELAY             | Integer | The delay in minutes to run this script. Don't set to execute this script only once.                                   |
| CKEY              | String  | The Chocolatey API Key to Push to the Public Repository.                                                               |
| AKEY              | String  | The Pushover Application Key. _optional_                                                                               |
| UKEY              | String  | The Pushover User Key. _optional_                                                                                      |
| MAX_PUSH_ATTEMPTS | Integer | Amount of attempts to push to chocolatey.org _default 1_                                                               |
| DATAPATH          | Sring   | The path to save version data. _default `/data/`_                                                                      |
| PACKAGES          | String  | A command separated list of package names to execute. _optional_                                                       |
| DEBUG             | Boolean | Enables debug mode if "true". Debug mode contains detailed output, recommended when creating new templates. _optional_ |

> If the `AKEY` or `UKEY` are not provided then script will not send out a Pushover.net notification.

## Creating your own template scripts
Use the `_.ps1` as a base to start from. All helper functions are in the `common.ps1` script and are commented. You can also look at the other scripts:-

* `burnaware` and `pdfshaper` shows you how to scrape a webpage to get the version number, the eula, the changelog and include the download installers in the package.
* `roccatswarm` shows you how to process data from a json api and include a link to the installer (shim).
* `proxallium` shows you how to get data via github releases and include the installer into the package.

`main` is the main script that links in the `common` script and the others above.

> Make sure you set the environment vars `DEBUG="true"` and `PACKAGES="yournewpackagename"` in your test environment so that you get more verbose output and only test your package instead of the others included.