FROM kosdk/choco:ps

LABEL maintainer="stewart.cossey@gmail.com"

RUN apt-get update && apt-get install -y \
    procps \
    && rm -rf /var/lib/apt/lists/*

RUN pwsh -Command "Install-Module -Name PowerShellPushOver -Force"

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD [ "ps -e | grep pwsh" ]

COPY *.ps1 /ps/
COPY templates/ /ps/templates/
CMD ["pwsh", "/ps/main.ps1"]
