FROM kosdk/choco:ps

LABEL maintainer="stewart.cossey@gmail.com"

RUN pwsh -Command "Install-Module -Name PowerShellPushOver -Force"

COPY *.ps1 /ps/
COPY templates/ /ps/templates/
CMD ["pwsh", "/ps/main.ps1"]