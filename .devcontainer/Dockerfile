
ARG TAG=7.0.0-alpine-3.13
FROM mcr.microsoft.com/azure-powershell:${TAG}

# [Option] Install zsh
ARG INSTALL_ZSH="true"

# Install needed packages and setup non-root user. Use a separate RUN statement to add your own dependencies.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
COPY common-alpine.sh /tmp/library-scripts/
RUN apk update && ash /tmp/library-scripts/common-alpine.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" \
    && rm -rf /tmp/library-scripts

# ** [Optional] Uncomment this section to install additional packages. **
# RUN apk update \
#     && apk add --no-cache <your-package-list-here>
RUN pwsh -Command  "& { \
    # Install Pester
    Install-Module -Name 'Pester' -RequiredVersion '5.3.1'  -AcceptLicense -Force; \
    # Turn off autosaving Azure credentials. Login information will be forgotten the next time you start a PowerShell process.
    Disable-AzContextAutosave; \
}"
